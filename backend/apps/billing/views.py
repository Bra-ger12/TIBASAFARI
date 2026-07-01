from decimal import Decimal

from drf_spectacular.utils import extend_schema
from rest_framework import filters, mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.views import APIView

from apps.billing.models import Invoice, Payment, SavedPaymentMethod
from apps.billing.serializers import (
    AddPaymentMethodSerializer,
    GenerateInvoiceSerializer,
    InvoiceSerializer,
    PaymentQueueSerializer,
    PaymentSerializer,
    RecordPaymentSerializer,
    RejectPaymentSerializer,
    SavedPaymentMethodSerializer,
    SubmitPaymentSerializer,
)
from apps.billing.services import InvoiceService
from apps.core.responses import success_response
from apps.rbac.permissions import RBACPermission
from apps.trips.models import Trip
from rest_framework.permissions import IsAuthenticated


class InvoiceViewSet(viewsets.ModelViewSet):
    serializer_class = InvoiceSerializer
    permission_classes = [RBACPermission]
    service = InvoiceService()
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ["invoice_number", "patient__email", "patient__full_name"]
    ordering_fields = ["created_at", "total_amount", "status", "due_date"]
    http_method_names = ["get", "patch", "delete", "head", "options"]  # no direct POST
    permission_map = {
        "list": "manage_trips",
        "retrieve": "manage_trips",
        "partial_update": "manage_trips",
        "destroy": "manage_trips",
        "generate": "manage_trips",
        "record_payment": "manage_trips",
        "my_invoices": "create_trip",
        "submit_payment": "create_trip",
    }

    def get_queryset(self):
        from apps.rbac.permissions import has_permission

        qs = Invoice.objects.select_related("trip", "patient").prefetch_related("payments")
        if has_permission(self.request.user, "manage_trips"):
            status_filter = self.request.query_params.get("status")
            if status_filter:
                qs = qs.filter(status=status_filter)
            return qs
        return qs.filter(patient=self.request.user)

    @extend_schema(request=GenerateInvoiceSerializer, responses={201: InvoiceSerializer})
    @action(detail=False, methods=["post"])
    def generate(self, request):
        serializer = GenerateInvoiceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            trip = Trip.objects.get(id=data["trip_id"])
        except Trip.DoesNotExist:
            return success_response(None, "Trip not found", status=status.HTTP_404_NOT_FOUND)

        invoice = self.service.create_for_trip(
            trip=trip,
            distance_km=data["distance_km"],
            duration_minutes=data["duration_minutes"],
            discount=data["discount"],
            tax_rate=data["tax_rate"],
        )
        return success_response(
            InvoiceSerializer(invoice).data,
            "Invoice generated",
            status=status.HTTP_201_CREATED,
        )

    @extend_schema(request=RecordPaymentSerializer, responses={200: InvoiceSerializer})
    @action(detail=True, methods=["post"], url_path="record-payment")
    def record_payment(self, request, pk=None):
        invoice = self.get_object()
        serializer = RecordPaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        self.service.record_payment(
            invoice,
            amount=data["amount"],
            method=data["method"],
            reference=data.get("reference", ""),
            recorded_by=request.user,
        )
        return success_response(InvoiceSerializer(invoice).data, "Payment recorded")

    @extend_schema(request=SubmitPaymentSerializer, responses={201: PaymentSerializer})
    @action(detail=True, methods=["post"], url_path="submit-payment")
    def submit_payment(self, request, pk=None):
        invoice = self.get_object()
        if invoice.status in {
            Invoice.Status.PAID,
            Invoice.Status.CANCELLED,
            Invoice.Status.REFUNDED,
        }:
            return success_response(
                None,
                "This invoice cannot accept a new payment",
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = SubmitPaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        payment = self.service.submit_payment(
            invoice,
            amount=data["amount"],
            method=data["method"],
            reference=data.get("reference", ""),
            notes=data.get("notes", ""),
        )
        return success_response(
            PaymentSerializer(payment).data,
            "Payment submitted for verification",
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=["get"], url_path="my-invoices")
    def my_invoices(self, request):
        qs = Invoice.objects.filter(patient=request.user).select_related("trip").prefetch_related("payments")
        page = self.paginate_queryset(qs)
        serializer = InvoiceSerializer(page or qs, many=True)
        if page is not None:
            return self.get_paginated_response(serializer.data)
        return success_response(serializer.data)


class PaymentViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Staff-facing queue for reviewing self-reported (submit_payment) payments.

    Lists PENDING payments by default so dispatch/finance can verify or
    reject them without going through the Django admin.
    """

    serializer_class = PaymentQueueSerializer
    permission_classes = [RBACPermission]
    service = InvoiceService()
    filter_backends = [filters.OrderingFilter]
    ordering_fields = ["created_at", "amount"]
    permission_map = {
        "list": "manage_trips",
        "verify": "manage_trips",
        "reject": "manage_trips",
    }

    def get_queryset(self):
        qs = Payment.objects.select_related("invoice", "invoice__patient")
        status_filter = self.request.query_params.get("status", Payment.Status.PENDING)
        if status_filter and status_filter.upper() != "ALL":
            qs = qs.filter(status=status_filter.upper())
        return qs

    @action(detail=True, methods=["post"])
    def verify(self, request, pk=None):
        payment = self.service.verify_payment(self.get_object(), verified_by=request.user)
        return success_response(PaymentQueueSerializer(payment).data, "Payment verified")

    @action(detail=True, methods=["post"])
    def reject(self, request, pk=None):
        serializer = RejectPaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payment = self.service.reject_payment(
            self.get_object(), reason=serializer.validated_data.get("reason", "")
        )
        return success_response(PaymentQueueSerializer(payment).data, "Payment rejected")


class SavedPaymentMethodViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """A patient's own saved payment methods (display-only, no real gateway)."""

    serializer_class = SavedPaymentMethodSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return SavedPaymentMethod.objects.filter(patient=self.request.user)

    def create(self, request, *args, **kwargs):
        serializer = AddPaymentMethodSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        is_first = not SavedPaymentMethod.objects.filter(patient=request.user).exists()
        method = SavedPaymentMethod.objects.create(
            patient=request.user,
            method_type=serializer.validated_data["method_type"],
            label=serializer.to_label(),
            is_default=is_first,
        )
        return success_response(
            SavedPaymentMethodSerializer(method).data,
            "Payment method added",
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["post"], url_path="set-default")
    def set_default(self, request, pk=None):
        method = self.get_object()
        SavedPaymentMethod.objects.filter(patient=request.user).update(is_default=False)
        method.is_default = True
        method.save(update_fields=["is_default"])
        return success_response(SavedPaymentMethodSerializer(method).data, "Default updated")
