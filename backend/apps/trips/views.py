from rest_framework import exceptions, filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser

from apps.core.responses import success_response
from apps.rbac.permissions import RBACPermission, has_permission
from apps.trips.models import RecurringSchedule, Trip, TripRating
from apps.trips.serializers import (
    AssignDriverSerializer,
    FareBreakdownSerializer,
    FareEstimateRequestSerializer,
    RecurringScheduleSerializer,
    SendTripMessageSerializer,
    TripCreateSerializer,
    TripMessageSerializer,
    TripRatingCreateSerializer,
    TripRatingSerializer,
    TripSerializer,
)
from apps.trips.services import TripService


class TripViewSet(viewsets.ModelViewSet):
    serializer_class = TripSerializer
    permission_classes = [RBACPermission]
    service = TripService()
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = [
        "pickup_address",
        "destination_address",
        "patient__email",
        "driver__email",
        "patient__full_name",
    ]
    ordering_fields = ["scheduled_at", "created_at", "updated_at", "status"]
    permission_map = {
        "list": "manage_trips",
        "retrieve": "view_own_trips",
        "create": "create_trip",
        "update": "manage_trips",
        "partial_update": "manage_trips",
        "destroy": "manage_trips",
        "assign_driver": "assign_driver",
        "accept": "update_trip_status",
        "reject": "update_trip_status",
        "start": "update_trip_status",
        "arrive": "update_trip_status",
        "complete": "update_trip_status",
        "cancel": "cancel_trip",
        "rate": "view_own_trips",
        "messages": "trip_messages",
        "estimate_fare": "create_trip",
    }

    def get_serializer_class(self):
        if self.action == "create":
            return TripCreateSerializer
        return super().get_serializer_class()

    def get_queryset(self):
        queryset = Trip.objects.select_related(
            "patient", "driver", "recurring_schedule", "destination_facility"
        )
        status_value = self.request.query_params.get("status")
        if status_value:
            # admin_web's Active Trips screen passes a comma-separated list
            # (e.g. "ASSIGNED,ACCEPTED,EN_ROUTE,ARRIVED") — an exact-match
            # filter on that literal joined string never matches any trip,
            # so always split and use __in even for a single value.
            statuses = [s.strip() for s in status_value.split(",") if s.strip()]
            queryset = queryset.filter(status__in=statuses)
        if has_permission(self.request.user, "manage_trips"):
            return queryset
        if has_permission(self.request.user, "view_assigned_trips"):
            return queryset.filter(driver=self.request.user)
        return queryset.filter(patient=self.request.user)

    def perform_create(self, serializer):
        patient = serializer.validated_data.pop("patient", self.request.user)
        trip = self.service.create_trip(patient=patient, **serializer.validated_data)
        serializer.instance = trip

    @action(detail=False, methods=["post"], url_path="estimate-fare")
    def estimate_fare(self, request):
        """Pre-booking fare quote — POST /api/v1/trips/estimate-fare/.
        Does not touch the database; the patient app calls this as they
        pick pickup/destination, before submitting the actual booking."""
        from apps.billing.services import FareEstimator

        serializer = FareEstimateRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        breakdown = FareEstimator().estimate(
            pickup_lat=data["pickup_latitude"],
            pickup_lng=data["pickup_longitude"],
            dest_lat=data["destination_latitude"],
            dest_lng=data["destination_longitude"],
            service_type=data.get("service_type", "basic"),
            waiting_minutes=data.get("waiting_minutes", 0),
            scheduled_at=data.get("scheduled_at"),
        )
        return success_response(
            FareBreakdownSerializer(breakdown).data, "Fare estimate calculated"
        )

    @action(detail=True, methods=["post"], url_path="assign-driver")
    def assign_driver(self, request, pk=None):
        trip = self.get_object()
        serializer = AssignDriverSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        trip = self.service.assign_driver(trip, driver=serializer.context["driver"])
        return success_response(TripSerializer(trip).data, "Driver assigned")

    @action(detail=True, methods=["post"])
    def accept(self, request, pk=None):
        trip = self.service.accept_trip(self.get_object(), driver=request.user)
        return success_response(TripSerializer(trip).data, "Trip accepted")

    @action(detail=True, methods=["post"])
    def reject(self, request, pk=None):
        trip = self.service.reject_trip(self.get_object(), driver=request.user)
        return success_response(TripSerializer(trip).data, "Trip rejected")

    @action(detail=True, methods=["post"])
    def start(self, request, pk=None):
        trip = self.service.start_trip(self.get_object(), driver=request.user)
        return success_response(TripSerializer(trip).data, "Trip started")

    @action(detail=True, methods=["post"])
    def arrive(self, request, pk=None):
        trip = self.service.arrive_trip(self.get_object(), driver=request.user)
        return success_response(TripSerializer(trip).data, "Trip marked arrived")

    @action(detail=True, methods=["post"], parser_classes=[MultiPartParser, FormParser, JSONParser])
    def complete(self, request, pk=None):
        distance_km = request.data.get("distance_km")
        duration_minutes = request.data.get("duration_minutes")
        trip = self.service.complete_trip(
            self.get_object(),
            driver=request.user,
            distance_km=distance_km,
            duration_minutes=duration_minutes,
            signature=request.FILES.get("signature"),
            proof_photo=request.FILES.get("proof_photo"),
        )
        return success_response(TripSerializer(trip).data, "Trip completed")

    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        trip = self.service.cancel_trip(self.get_object(), user=request.user)
        return success_response(TripSerializer(trip).data, "Trip cancelled")

    @action(detail=True, methods=["post"])
    def rate(self, request, pk=None):
        trip = self.get_object()
        if trip.patient != request.user:
            raise exceptions.PermissionDenied("You can only rate your own trips")
        if trip.status != Trip.Status.COMPLETED:
            raise exceptions.ValidationError("Only completed trips can be rated")
        if hasattr(trip, "rating"):
            raise exceptions.ValidationError("This trip has already been rated")
        serializer = TripRatingCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        rating = TripRating.objects.create(
            trip=trip,
            patient=request.user,
            score=serializer.validated_data["score"],
            comment=serializer.validated_data.get("comment", ""),
        )
        return success_response(
            TripRatingSerializer(rating).data,
            "Trip rated successfully",
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["get", "post"])
    def messages(self, request, pk=None):
        trip = self.get_object()
        if request.method == "POST":
            serializer = SendTripMessageSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            message = self.service.send_trip_message(
                trip, sender=request.user, body=serializer.validated_data["body"]
            )
            return success_response(
                TripMessageSerializer(message).data,
                "Message sent",
                status=status.HTTP_201_CREATED,
            )
        self.service._assert_participant(trip, request.user)
        thread = trip.messages.select_related("sender").all()
        return success_response(TripMessageSerializer(thread, many=True).data)


class RecurringScheduleViewSet(viewsets.ModelViewSet):
    serializer_class = RecurringScheduleSerializer
    permission_classes = [RBACPermission]
    service = TripService()
    filter_backends = [filters.OrderingFilter]
    ordering_fields = ["created_at", "start_date"]
    permission_map = {
        "list": "create_trip",
        "retrieve": "create_trip",
        "create": "create_trip",
        "update": "create_trip",
        "partial_update": "create_trip",
        "destroy": "create_trip",
    }

    def get_queryset(self):
        if has_permission(self.request.user, "manage_trips"):
            return RecurringSchedule.objects.select_related("patient")
        return RecurringSchedule.objects.filter(patient=self.request.user)

    def perform_create(self, serializer):
        schedule = serializer.save(patient=self.request.user)
        # Book the first occurrence synchronously so dispatch has something
        # to see/assign immediately, rather than waiting for the next
        # generate_recurring_trips cron run (see that management command
        # for how later occurrences get booked).
        self.service.book_recurring_occurrence(schedule, schedule.start_date)
        # Cursor for generate_recurring_trips — without this it would
        # re-book start_date as if it were still unbooked.
        schedule.last_generated_date = schedule.start_date
        schedule.save(update_fields=["last_generated_date"])
