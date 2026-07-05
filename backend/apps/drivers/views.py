from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import exceptions, filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView

from apps.core.responses import success_response
from apps.drivers.models import DriverDocument, DriverProfile
from apps.drivers.serializers import (
    AssignedTripSerializer,
    DriverAvailabilitySerializer,
    DriverDocumentReviewSerializer,
    DriverDocumentSerializer,
    DriverLocationSerializer,
    DriverProfileSerializer,
    DriverSignupSerializer,
    DriverSosSerializer,
)
from apps.drivers.services import DriverService
from apps.rbac.permissions import RBACPermission, has_permission
from apps.trips.models import Trip


class DriverSignupView(APIView):
    permission_classes = [AllowAny]
    serializer_class = DriverSignupSerializer

    @extend_schema(
        request=DriverSignupSerializer,
        responses={201: DriverProfileSerializer},
    )
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = serializer.save()
        return success_response(
            DriverProfileSerializer(profile).data,
            "Driver account created",
            status=status.HTTP_201_CREATED,
        )


class DriverProfileViewSet(viewsets.ModelViewSet):
    serializer_class = DriverProfileSerializer
    permission_classes = [RBACPermission]
    service = DriverService()
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ["user__email", "user__full_name", "license_number"]
    ordering_fields = ["created_at", "updated_at", "is_available"]
    permission_map = {
        "list": "manage_drivers",
        "retrieve": "manage_drivers",
        "create": "manage_drivers",
        "update": "manage_drivers",
        "partial_update": "manage_drivers",
        "destroy": "manage_drivers",
        "me": "view_assigned_trips",
        "availability": "view_assigned_trips",
        "location": "update_location",
        "assigned_trips": "view_assigned_trips",
        "documents": "view_assigned_trips",
        "review_document": "manage_drivers",
        "sos": "view_assigned_trips",
    }

    def get_queryset(self):
        queryset = DriverProfile.objects.select_related("user", "vehicle")
        if has_permission(self.request.user, "manage_drivers"):
            return queryset
        return queryset.filter(user=self.request.user)

    def perform_create(self, serializer):
        profile = self.service.create_profile(**serializer.validated_data)
        serializer.instance = profile

    def perform_update(self, serializer):
        profile = self.service.update_profile(
            serializer.instance,
            **serializer.validated_data,
        )
        serializer.instance = profile

    def _get_current_driver_profile(self):
        try:
            return DriverProfile.objects.get(user=self.request.user)
        except DriverProfile.DoesNotExist as exc:
            raise exceptions.NotFound(
                "No driver profile is linked to this account."
            ) from exc

    @action(detail=False, methods=["get", "patch"])
    def me(self, request):
        profile = self._get_current_driver_profile()
        if request.method == "PATCH":
            # Self-service edits are limited to license_number — vehicle
            # assignment and availability are managed via their own actions.
            allowed_fields = {"license_number"}
            data = {k: v for k, v in request.data.items() if k in allowed_fields}
            serializer = self.get_serializer(profile, data=data, partial=True)
            serializer.is_valid(raise_exception=True)
            self.perform_update(serializer)
        else:
            serializer = self.get_serializer(profile)
        return success_response(serializer.data)

    @action(detail=False, methods=["patch"])
    def availability(self, request):
        profile = self._get_current_driver_profile()
        serializer = DriverAvailabilitySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = self.service.set_availability(profile, **serializer.validated_data)
        return success_response(self.get_serializer(profile).data)

    @action(detail=False, methods=["patch"])
    def location(self, request):
        profile = self._get_current_driver_profile()
        serializer = DriverLocationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = self.service.update_location(profile, **serializer.validated_data)
        return success_response(self.get_serializer(profile).data)

    @action(detail=False, methods=["get"], url_path="assigned-trips")
    def assigned_trips(self, request):
        trips = Trip.objects.filter(driver=request.user).order_by("-scheduled_at")
        page = self.paginate_queryset(trips)
        serializer = AssignedTripSerializer(page or trips, many=True)
        if page is not None:
            return self.get_paginated_response(serializer.data)
        return success_response(serializer.data)

    @extend_schema(request=DriverDocumentSerializer, responses={201: DriverDocumentSerializer})
    @action(
        detail=False,
        methods=["get", "post"],
        parser_classes=[MultiPartParser, FormParser, JSONParser],
    )
    def documents(self, request):
        profile = self._get_current_driver_profile()
        if request.method == "POST":
            serializer = DriverDocumentSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            doc = DriverDocument.objects.create(
                driver=profile, **serializer.validated_data
            )
            return success_response(
                DriverDocumentSerializer(doc).data,
                "Document submitted for review",
                status=status.HTTP_201_CREATED,
            )
        docs = profile.documents.all()
        return success_response(DriverDocumentSerializer(docs, many=True).data)

    @extend_schema(
        request=DriverDocumentReviewSerializer, responses={200: DriverDocumentSerializer}
    )
    @action(detail=True, methods=["patch"], url_path="documents/(?P<document_id>[^/.]+)/review")
    def review_document(self, request, pk=None, document_id=None):
        """Admin/staff verify or reject a driver's uploaded document."""
        profile = self.get_object()
        document = get_object_or_404(DriverDocument, pk=document_id, driver=profile)
        serializer = DriverDocumentReviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        document.status = serializer.validated_data["status"]
        document.rejection_reason = serializer.validated_data.get("rejection_reason", "")
        document.reviewed_by = request.user
        document.reviewed_at = timezone.now()
        document.save(update_fields=["status", "rejection_reason", "reviewed_by", "reviewed_at"])
        return success_response(
            DriverDocumentSerializer(document, context=self.get_serializer_context()).data,
            "Document review saved",
        )

    @extend_schema(request=DriverSosSerializer)
    @action(detail=False, methods=["post"])
    def sos(self, request):
        profile = self._get_current_driver_profile()
        serializer = DriverSosSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        notified = self.service.trigger_sos(
            profile,
            message=data.get("message", ""),
            trip_id=data.get("trip_id"),
            latitude=data.get("latitude"),
            longitude=data.get("longitude"),
        )
        return success_response(
            {"notified": notified}, "Emergency alert sent to dispatch"
        )
