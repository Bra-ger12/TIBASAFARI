from rest_framework import filters, mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.serializers import UserSerializer
from apps.core.responses import success_response
from apps.patients.models import PatientProfile
from apps.patients.serializers import (
    PatientProfileSerializer,
    PatientSignupSerializer,
    PatientTripRequestSerializer,
)
from apps.patients.services import PatientService
from apps.rbac.permissions import RBACPermission, has_permission
from apps.trips.models import Trip
from apps.trips.services import TripService


class PatientSignupView(APIView):
    permission_classes = [AllowAny]
    serializer_class = PatientSignupSerializer

    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        data = {
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": UserSerializer(user).data,
        }
        return success_response(data, "Patient account created", status=status.HTTP_201_CREATED)


class PatientProfileViewSet(viewsets.ModelViewSet):
    serializer_class = PatientProfileSerializer
    permission_classes = [RBACPermission]
    service = PatientService()
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ["user__email", "user__full_name", "user__phone"]
    ordering_fields = ["created_at", "updated_at", "user__email"]
    permission_map = {
        "list": "manage_patients",
        "retrieve": "view_own_trips",
        "create": "manage_patients",
        "update": "manage_patients",
        "partial_update": "manage_patients",
        "destroy": "manage_patients",
        "me": "view_own_trips",
        "trip_history": "view_own_trips",
    }

    def get_queryset(self):
        queryset = PatientProfile.objects.select_related("user")
        if has_permission(self.request.user, "manage_patients"):
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

    @action(detail=False, methods=["get", "patch"])
    def me(self, request):
        profile = PatientProfile.objects.get(user=request.user)
        if request.method == "PATCH":
            serializer = self.get_serializer(profile, data=request.data, partial=True)
            serializer.is_valid(raise_exception=True)
            self.perform_update(serializer)
        else:
            serializer = self.get_serializer(profile)
        return success_response(serializer.data)

    @action(detail=False, methods=["get"], url_path="trip-history")
    def trip_history(self, request):
        trips = Trip.objects.filter(patient=request.user).order_by("-scheduled_at")
        page = self.paginate_queryset(trips)
        serializer = PatientTripRequestSerializer(page or trips, many=True)
        if page is not None:
            return self.get_paginated_response(serializer.data)
        return success_response(serializer.data)


class PatientTripRequestViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = PatientTripRequestSerializer
    permission_classes = [RBACPermission]
    permission_map = {"list": "view_own_trips", "create": "create_trip"}
    service = TripService()

    def get_queryset(self):
        return Trip.objects.filter(patient=self.request.user).order_by("-scheduled_at")

    def perform_create(self, serializer):
        trip = self.service.create_trip(
            patient=self.request.user,
            **serializer.validated_data,
        )
        serializer.instance = trip

