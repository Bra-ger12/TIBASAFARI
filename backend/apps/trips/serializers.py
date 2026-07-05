from rest_framework import serializers

from apps.accounts.models import User
from apps.rbac.permissions import has_role
from apps.trips.models import RecurringSchedule, Trip, TripMessage, TripRating


class TripSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source="patient.full_name", read_only=True)
    patient_email = serializers.EmailField(source="patient.email", read_only=True)
    driver_name = serializers.CharField(source="driver.full_name", read_only=True)
    driver_email = serializers.EmailField(source="driver.email", read_only=True)
    driver_phone = serializers.CharField(source="driver.phone", read_only=True)
    driver_vehicle_make = serializers.CharField(
        source="driver.driver_profile.vehicle.make", read_only=True
    )
    driver_vehicle_model = serializers.CharField(
        source="driver.driver_profile.vehicle.model", read_only=True
    )
    driver_vehicle_registration = serializers.CharField(
        source="driver.driver_profile.vehicle.registration_number", read_only=True
    )
    is_rated = serializers.SerializerMethodField()
    rating_score = serializers.SerializerMethodField()
    destination_facility_name = serializers.SerializerMethodField()

    def get_is_rated(self, obj):
        return hasattr(obj, "rating")

    def get_rating_score(self, obj):
        return obj.rating.score if hasattr(obj, "rating") else None

    def get_destination_facility_name(self, obj):
        return obj.destination_facility.name if obj.destination_facility_id else None

    class Meta:
        model = Trip
        fields = (
            "id",
            "patient",
            "patient_name",
            "patient_email",
            "driver",
            "driver_name",
            "driver_email",
            "driver_phone",
            "driver_vehicle_make",
            "driver_vehicle_model",
            "driver_vehicle_registration",
            "recurring_schedule",
            "pickup_address",
            "destination_address",
            "destination_facility",
            "destination_facility_name",
            "pickup_latitude",
            "pickup_longitude",
            "destination_latitude",
            "destination_longitude",
            "scheduled_at",
            "status",
            "mobility_aid",
            "service_level",
            "oxygen_required",
            "medical_escort_required",
            "iv_drip_required",
            "bariatric",
            "num_attendants",
            "special_requirements",
            "notes",
            "distance_km",
            "duration_minutes",
            "estimated_fare",
            "signature",
            "proof_photo",
            "accepted_at",
            "started_at",
            "arrived_at",
            "completed_at",
            "cancelled_at",
            "created_at",
            "updated_at",
            "is_rated",
            "rating_score",
        )
        read_only_fields = (
            "id",
            "patient_name",
            "patient_email",
            "driver_name",
            "driver_email",
            "driver_phone",
            "driver_vehicle_make",
            "driver_vehicle_model",
            "driver_vehicle_registration",
            "signature",
            "proof_photo",
            "accepted_at",
            "started_at",
            "arrived_at",
            "completed_at",
            "cancelled_at",
            "created_at",
            "updated_at",
            "is_rated",
            "rating_score",
            "destination_facility_name",
        )


class TripCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Trip
        fields = (
            "id",
            "pickup_address",
            "destination_address",
            "destination_facility",
            "pickup_latitude",
            "pickup_longitude",
            "destination_latitude",
            "destination_longitude",
            "scheduled_at",
            "mobility_aid",
            "service_level",
            "oxygen_required",
            "medical_escort_required",
            "iv_drip_required",
            "bariatric",
            "num_attendants",
            "special_requirements",
            "notes",
            "estimated_fare",
            "estimated_fare_breakdown",
            "recurring_schedule",
            "status",
        )
        read_only_fields = ("id", "status")


class FareEstimateRequestSerializer(serializers.Serializer):
    pickup_latitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    pickup_longitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    destination_latitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    destination_longitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    service_type = serializers.ChoiceField(
        choices=["basic", "wheelchair", "medical_equipment"],
        default="basic",
        required=False,
    )
    waiting_minutes = serializers.IntegerField(min_value=0, default=0, required=False)
    scheduled_at = serializers.DateTimeField(required=False)


class FareBreakdownSerializer(serializers.Serializer):
    distance_km = serializers.FloatField()
    base_fare = serializers.DecimalField(max_digits=10, decimal_places=2)
    distance_charge = serializers.DecimalField(max_digits=10, decimal_places=2)
    waiting_minutes = serializers.IntegerField()
    waiting_charge = serializers.DecimalField(max_digits=10, decimal_places=2)
    service_type = serializers.CharField()
    service_multiplier = serializers.DecimalField(max_digits=4, decimal_places=2)
    subtotal_after_multiplier = serializers.DecimalField(max_digits=10, decimal_places=2)
    is_peak_hour = serializers.BooleanField()
    peak_surcharge_amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    is_urban_zone = serializers.BooleanField()
    zone_surcharge_amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    minimum_fare = serializers.DecimalField(max_digits=10, decimal_places=2)
    total_fare = serializers.DecimalField(max_digits=10, decimal_places=2)


class AssignDriverSerializer(serializers.Serializer):
    driver_id = serializers.UUIDField()

    def validate_driver_id(self, value):
        try:
            driver = User.objects.get(id=value, is_active=True)
        except User.DoesNotExist as exc:
            raise serializers.ValidationError("Driver does not exist") from exc
        if not has_role(driver, "DRIVER"):
            raise serializers.ValidationError("User is not assigned the DRIVER role")
        self.context["driver"] = driver
        return value


class TripRatingCreateSerializer(serializers.Serializer):
    score = serializers.IntegerField(min_value=1, max_value=5)
    comment = serializers.CharField(required=False, allow_blank=True, default="")


class TripRatingSerializer(serializers.ModelSerializer):
    class Meta:
        model = TripRating
        fields = ("id", "score", "comment", "created_at")
        read_only_fields = ("id", "created_at")


class TripMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source="sender.full_name", read_only=True)

    class Meta:
        model = TripMessage
        fields = ("id", "trip", "sender", "sender_name", "body", "created_at")
        read_only_fields = ("id", "trip", "sender", "sender_name", "created_at")


class SendTripMessageSerializer(serializers.Serializer):
    body = serializers.CharField(max_length=2000, allow_blank=False)


class RecurringScheduleSerializer(serializers.ModelSerializer):
    class Meta:
        model = RecurringSchedule
        fields = (
            "id",
            "patient",
            "pickup_address",
            "destination_address",
            "pickup_latitude",
            "pickup_longitude",
            "destination_latitude",
            "destination_longitude",
            "pickup_time",
            "frequency",
            "days_of_week",
            "special_requirements",
            "is_active",
            "start_date",
            "end_date",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")
