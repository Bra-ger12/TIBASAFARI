from rest_framework import serializers

from apps.accounts.models import User
from apps.rbac.permissions import has_role
from apps.trips.models import RecurringSchedule, Trip, TripMessage, TripRating


class TripSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source="patient.full_name", read_only=True)
    patient_email = serializers.EmailField(source="patient.email", read_only=True)
    driver_name = serializers.CharField(source="driver.full_name", read_only=True)
    driver_email = serializers.EmailField(source="driver.email", read_only=True)
    is_rated = serializers.SerializerMethodField()
    rating_score = serializers.SerializerMethodField()

    def get_is_rated(self, obj):
        return hasattr(obj, "rating")

    def get_rating_score(self, obj):
        return obj.rating.score if hasattr(obj, "rating") else None

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
            "recurring_schedule",
            "pickup_address",
            "destination_address",
            "pickup_latitude",
            "pickup_longitude",
            "destination_latitude",
            "destination_longitude",
            "scheduled_at",
            "status",
            "mobility_aid",
            "service_level",
            "oxygen_required",
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


class TripCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Trip
        fields = (
            "id",
            "pickup_address",
            "destination_address",
            "pickup_latitude",
            "pickup_longitude",
            "destination_latitude",
            "destination_longitude",
            "scheduled_at",
            "mobility_aid",
            "service_level",
            "oxygen_required",
            "bariatric",
            "num_attendants",
            "special_requirements",
            "notes",
            "estimated_fare",
            "recurring_schedule",
            "status",
        )
        read_only_fields = ("id", "status")


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
