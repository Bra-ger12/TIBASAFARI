from django.db import transaction
from django.db.models import Avg, Count, Q, Sum
from rest_framework import serializers

from apps.accounts.models import User
from apps.drivers.models import DriverDocument, DriverProfile
from apps.rbac.models import Permission, Role, UserRole
from apps.trips.models import Trip, TripAssignmentEvent, TripRating


class DriverProfileSerializer(serializers.ModelSerializer):
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_full_name = serializers.CharField(source="user.full_name", read_only=True)
    user_phone = serializers.CharField(source="user.phone", read_only=True)
    vehicle_registration = serializers.CharField(
        source="vehicle.registration_number",
        read_only=True,
    )
    trips_count = serializers.SerializerMethodField()
    completed_trips_count = serializers.SerializerMethodField()
    revenue = serializers.SerializerMethodField()
    acceptance_rate = serializers.SerializerMethodField()
    rating = serializers.SerializerMethodField()
    rating_count = serializers.SerializerMethodField()
    documents = serializers.SerializerMethodField()

    class Meta:
        model = DriverProfile
        fields = (
            "id",
            "user",
            "user_email",
            "user_full_name",
            "user_phone",
            "license_number",
            "vehicle",
            "vehicle_registration",
            "is_available",
            "trips_count",
            "completed_trips_count",
            "revenue",
            "acceptance_rate",
            "rating",
            "rating_count",
            "documents",
            "current_latitude",
            "current_longitude",
            "last_location_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "user_email",
            "user_full_name",
            "user_phone",
            "vehicle_registration",
            "trips_count",
            "completed_trips_count",
            "revenue",
            "acceptance_rate",
            "rating",
            "rating_count",
            "documents",
            "last_location_at",
            "created_at",
            "updated_at",
        )

    def get_documents(self, obj):
        return DriverDocumentSerializer(
            obj.documents.all(), many=True, context=self.context
        ).data

    def get_trips_count(self, obj):
        return Trip.objects.filter(driver=obj.user).count()

    def get_completed_trips_count(self, obj):
        return Trip.objects.filter(driver=obj.user, status=Trip.Status.COMPLETED).count()

    def get_revenue(self, obj):
        total = Trip.objects.filter(
            driver=obj.user, status=Trip.Status.COMPLETED
        ).aggregate(total=Sum("final_fare"))["total"]
        return total or 0

    def get_acceptance_rate(self, obj):
        counts = TripAssignmentEvent.objects.filter(driver=obj.user).aggregate(
            accepted=Count("id", filter=Q(event_type=TripAssignmentEvent.EventType.ACCEPTED)),
            rejected=Count("id", filter=Q(event_type=TripAssignmentEvent.EventType.REJECTED)),
        )
        decided = counts["accepted"] + counts["rejected"]
        if decided == 0:
            return None
        return round(counts["accepted"] / decided * 100, 1)

    def _rating_stats(self, obj):
        # Computed on read rather than stored/recalculated on write — always
        # accurate, and TripRating is created directly in TripViewSet.rate()
        # with no signal/hook that could otherwise trigger a recompute.
        return TripRating.objects.filter(trip__driver=obj.user).aggregate(
            avg=Avg("score"), count=Count("id")
        )

    def get_rating(self, obj):
        avg = self._rating_stats(obj)["avg"]
        return round(avg, 1) if avg is not None else 0.0

    def get_rating_count(self, obj):
        return self._rating_stats(obj)["count"]

    def validate_user(self, value):
        queryset = DriverProfile.objects.filter(user=value)
        if self.instance:
            queryset = queryset.exclude(pk=self.instance.pk)
        if queryset.exists():
            raise serializers.ValidationError("Driver profile already exists")
        return value


class DriverDocumentSerializer(serializers.ModelSerializer):
    doc_type_display = serializers.CharField(
        source="get_doc_type_display", read_only=True
    )

    class Meta:
        model = DriverDocument
        fields = (
            "id",
            "doc_type",
            "doc_type_display",
            "file",
            "expiry_date",
            "status",
            "rejection_reason",
            "uploaded_at",
            "reviewed_at",
        )
        read_only_fields = (
            "id",
            "doc_type_display",
            "status",
            "rejection_reason",
            "uploaded_at",
            "reviewed_at",
        )


class DriverDocumentReviewSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=(DriverDocument.Status.VERIFIED, DriverDocument.Status.REJECTED)
    )
    rejection_reason = serializers.CharField(required=False, allow_blank=True, default="")

    def validate(self, attrs):
        if attrs["status"] == DriverDocument.Status.REJECTED and not attrs.get(
            "rejection_reason"
        ):
            raise serializers.ValidationError(
                {"rejection_reason": "A reason is required when rejecting a document."}
            )
        return attrs


class DriverSosSerializer(serializers.Serializer):
    message = serializers.CharField(required=False, allow_blank=True, default="")
    trip_id = serializers.UUIDField(required=False, allow_null=True, default=None)
    latitude = serializers.DecimalField(
        max_digits=9, decimal_places=6, required=False, allow_null=True, default=None
    )
    longitude = serializers.DecimalField(
        max_digits=9, decimal_places=6, required=False, allow_null=True, default=None
    )


class DriverAvailabilitySerializer(serializers.Serializer):
    is_available = serializers.BooleanField()


class DriverLocationSerializer(serializers.Serializer):
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6)


class AssignedTripSerializer(serializers.ModelSerializer):
    patient_email = serializers.EmailField(source="patient.email", read_only=True)
    patient_name = serializers.CharField(source="patient.full_name", read_only=True)
    patient_phone = serializers.CharField(source="patient.phone", read_only=True)

    class Meta:
        model = Trip
        fields = (
            "id",
            "patient",
            "patient_email",
            "patient_name",
            "patient_phone",
            "pickup_address",
            "destination_address",
            "scheduled_at",
            "status",
            "special_requirements",
            "notes",
            "distance_km",
            "duration_minutes",
            "estimated_fare",
            "completed_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = fields


class GoogleAuthSerializer(serializers.Serializer):
    id_token = serializers.CharField(write_only=True)


class DriverSignupSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    phone_number = serializers.CharField(
        max_length=32,
        required=False,
        allow_blank=True,
    )
    license_number = serializers.CharField(max_length=80)
    password = serializers.CharField(
        write_only=True,
        min_length=6,
        trim_whitespace=False,
    )
    confirm_password = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate_email(self, value):
        email = value.strip().lower()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("Email is already registered")
        return email

    def validate_license_number(self, value):
        license_number = value.strip().upper()
        if DriverProfile.objects.filter(
            license_number__iexact=license_number,
        ).exists():
            raise serializers.ValidationError("Driver license is already registered")
        return license_number

    def validate(self, attrs):
        if attrs["password"] != attrs["confirm_password"]:
            raise serializers.ValidationError(
                {"confirm_password": "Passwords do not match"}
            )
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        validated_data.pop("confirm_password")
        password = validated_data.pop("password")
        license_number = validated_data.pop("license_number")

        user = User.objects.create_user(
            password=password,
            status=User.Status.ACTIVE,
            is_active=True,
            **validated_data,
        )
        UserRole.objects.get_or_create(user=user, role=self._driver_role())
        return DriverProfile.objects.create(
            user=user,
            license_number=license_number,
        )

    def _driver_role(self):
        role, _ = Role.objects.get_or_create(
            code="DRIVER",
            defaults={"name": "DRIVER", "description": "Driver user"},
        )
        permission_names = {
            "view_assigned_trips": "View assigned trips",
            "update_trip_status": "Update trip status",
            "update_location": "Update driver location",
        }
        permissions = []
        for code, name in permission_names.items():
            permission, _ = Permission.objects.get_or_create(
                code=code,
                defaults={"name": name},
            )
            permissions.append(permission)
        role.permissions.add(*permissions)
        return role
