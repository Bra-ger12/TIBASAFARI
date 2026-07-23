import uuid

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


class RecurringSchedule(models.Model):
    """Defines a recurring ride pattern. Individual Trip rows are generated from it."""

    class Frequency(models.TextChoices):
        DAILY = "DAILY", "Daily"
        WEEKLY = "WEEKLY", "Weekly"
        BIWEEKLY = "BIWEEKLY", "Every Two Weeks"
        MONTHLY = "MONTHLY", "Monthly"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="recurring_schedules",
        on_delete=models.CASCADE,
    )
    pickup_address = models.CharField(max_length=255)
    destination_address = models.CharField(max_length=255)
    pickup_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    pickup_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    destination_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    destination_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    pickup_time = models.TimeField()
    frequency = models.CharField(max_length=20, choices=Frequency.choices)
    days_of_week = models.JSONField(default=list, blank=True, help_text="[0=Mon..6=Sun] for WEEKLY")
    special_requirements = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    start_date = models.DateField()
    end_date = models.DateField(null=True, blank=True)
    # Cursor for generate_recurring_trips: the last occurrence date a Trip
    # was already booked for. Set to start_date as soon as the first trip
    # is booked (see RecurringScheduleViewSet.perform_create), so the daily
    # job knows to look strictly after this date rather than re-booking it.
    last_generated_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"RecurringSchedule({self.patient_id}, {self.frequency})"


class Trip(models.Model):
    class Status(models.TextChoices):
        REQUESTED = "REQUESTED", "Requested"
        ASSIGNED = "ASSIGNED", "Assigned"
        ACCEPTED = "ACCEPTED", "Accepted"
        EN_ROUTE = "EN_ROUTE", "En route"
        ARRIVED = "ARRIVED", "Arrived"
        COMPLETED = "COMPLETED", "Completed"
        CANCELLED = "CANCELLED", "Cancelled"

    class MobilityAid(models.TextChoices):
        NONE = "NONE", "None"
        MANUAL_WHEELCHAIR = "MANUAL_WC", "Manual Wheelchair"
        POWER_WHEELCHAIR = "POWER_WC", "Power Wheelchair"
        STRETCHER = "STRETCHER", "Stretcher"
        AMBULATORY = "AMBULATORY", "Ambulatory (walking)"

    class ServiceLevel(models.TextChoices):
        CURB_TO_CURB = "CURB", "Curb-to-Curb"
        DOOR_TO_DOOR = "DOOR", "Door-to-Door"
        DOOR_THROUGH_DOOR = "DTD", "Door-Through-Door"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="patient_trips",
        on_delete=models.PROTECT,
    )
    driver = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="driver_trips",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
    )
    recurring_schedule = models.ForeignKey(
        RecurringSchedule,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="trips",
    )
    # Optional link to the picked destination facility. destination_address/
    # lat/lng below are copied at booking time and are the source of truth
    # for the trip regardless of this FK, so if the facility is later
    # deleted (SET_NULL) the trip's own destination data is unaffected.
    destination_facility = models.ForeignKey(
        "facilities.HealthFacility",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="trips",
    )

    # Addresses & coordinates
    pickup_address = models.CharField(max_length=255)
    destination_address = models.CharField(max_length=255)
    pickup_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    pickup_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    destination_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    destination_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)

    # Scheduling
    scheduled_at = models.DateTimeField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.REQUESTED)

    # Patient mobility & service level
    mobility_aid = models.CharField(
        max_length=20, choices=MobilityAid.choices, default=MobilityAid.NONE
    )
    service_level = models.CharField(
        max_length=10, choices=ServiceLevel.choices, default=ServiceLevel.CURB_TO_CURB
    )
    oxygen_required = models.BooleanField(default=False)
    medical_escort_required = models.BooleanField(default=False)
    iv_drip_required = models.BooleanField(default=False)
    bariatric = models.BooleanField(default=False)
    num_attendants = models.PositiveSmallIntegerField(default=0, help_text="Number of accompanying attendants")
    special_requirements = models.TextField(blank=True)
    notes = models.TextField(blank=True)

    # Metrics (filled in on completion)
    distance_km = models.DecimalField(max_digits=8, decimal_places=3, null=True, blank=True)
    duration_minutes = models.PositiveIntegerField(null=True, blank=True)

    # Fare quoted to the patient before booking (see FareEstimator /
    # POST /trips/estimate-fare/) — client may attach it at booking time.
    estimated_fare = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    estimated_fare_breakdown = models.JSONField(default=dict, blank=True)

    # Actual fare computed on completion (see TripService.complete_trip).
    final_fare = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    final_fare_breakdown = models.JSONField(default=dict, blank=True)

    # Proof of service (captured by the driver on completion)
    signature = models.ImageField(upload_to="trip_proofs/signatures/", null=True, blank=True)
    proof_photo = models.ImageField(upload_to="trip_proofs/photos/", null=True, blank=True)

    # Timestamps
    accepted_at = models.DateTimeField(null=True, blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    arrived_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-scheduled_at",)
        indexes = [
            models.Index(fields=("status", "scheduled_at")),
            models.Index(fields=("patient", "status")),
            models.Index(fields=("driver", "status")),
        ]

    def __str__(self) -> str:
        return f"Trip({self.id}, {self.status})"

    def needs_wheelchair_vehicle(self) -> bool:
        return self.mobility_aid in {
            Trip.MobilityAid.MANUAL_WHEELCHAIR,
            Trip.MobilityAid.POWER_WHEELCHAIR,
        }


class TripAssignmentEvent(models.Model):
    """Records each assign/accept/reject decision for a driver on a trip, so
    a driver's trip-acceptance rate can be computed later. Trip.status only
    holds the *current* state, so a reassignment after a rejection would
    otherwise leave no trace of who declined it."""

    class EventType(models.TextChoices):
        ASSIGNED = "ASSIGNED", "Assigned"
        ACCEPTED = "ACCEPTED", "Accepted"
        REJECTED = "REJECTED", "Rejected"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    trip = models.ForeignKey(Trip, related_name="assignment_events", on_delete=models.CASCADE)
    driver = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="trip_assignment_events",
        on_delete=models.CASCADE,
    )
    event_type = models.CharField(max_length=10, choices=EventType.choices)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("driver", "event_type"))]

    def __str__(self) -> str:
        return f"TripAssignmentEvent({self.trip_id}, {self.driver_id}, {self.event_type})"


class TripMessage(models.Model):
    """A single chat message exchanged between the driver, patient, and dispatch on a trip."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    trip = models.ForeignKey(Trip, related_name="messages", on_delete=models.CASCADE)
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="trip_messages_sent",
        on_delete=models.CASCADE,
    )
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("created_at",)

    def __str__(self) -> str:
        return f"TripMessage({self.trip_id}, {self.sender_id})"


class TripRating(models.Model):
    """Patient rating for a completed trip (1–5 stars + optional comment)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    trip = models.OneToOneField(
        Trip, related_name="rating", on_delete=models.CASCADE
    )
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="given_ratings",
        on_delete=models.CASCADE,
    )
    score = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)]
    )
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self) -> str:
        return f"TripRating({self.trip_id}, {self.score}★)"
