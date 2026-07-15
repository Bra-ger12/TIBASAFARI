from django.db import transaction
from rest_framework import serializers

from apps.accounts.models import User
from apps.core.media import build_secure_media_url
from apps.patients.models import PatientDocument, PatientProfile
from apps.patients.services import get_or_create_patient_role
from apps.rbac.models import UserRole
from apps.trips.models import Trip


class PatientDocumentSerializer(serializers.ModelSerializer):
    doc_type_display = serializers.CharField(
        source="get_doc_type_display", read_only=True
    )

    class Meta:
        model = PatientDocument
        fields = (
            "id",
            "doc_type",
            "doc_type_display",
            "file",
            "description",
            "uploaded_at",
        )
        read_only_fields = ("id", "doc_type_display", "uploaded_at")

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["file"] = build_secure_media_url(self.context.get("request"), instance.file)
        return data


class PatientProfileSerializer(serializers.ModelSerializer):
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_full_name = serializers.CharField(source="user.full_name", read_only=True)
    user_phone = serializers.CharField(source="user.phone", read_only=True)
    trips_count = serializers.SerializerMethodField()
    documents = serializers.SerializerMethodField()

    class Meta:
        model = PatientProfile
        fields = (
            "id",
            "user",
            "user_email",
            "user_full_name",
            "user_phone",
            "date_of_birth",
            "emergency_contact_name",
            "emergency_contact_phone",
            "medical_notes",
            "mobility_needs",
            "oxygen_required",
            "medical_escort_required",
            "iv_drip_required",
            "default_pickup_address",
            "trips_count",
            "documents",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "user_email",
            "user_full_name",
            "user_phone",
            "trips_count",
            "documents",
            "created_at",
            "updated_at",
        )

    def get_trips_count(self, obj):
        from apps.trips.models import Trip
        return Trip.objects.filter(patient=obj.user).count()

    def get_documents(self, obj):
        return PatientDocumentSerializer(
            obj.documents.all(), many=True, context=self.context
        ).data

    def validate_user(self, value):
        queryset = PatientProfile.objects.filter(user=value)
        if self.instance:
            queryset = queryset.exclude(pk=self.instance.pk)
        if queryset.exists():
            raise serializers.ValidationError("Patient profile already exists")
        return value


class PatientTripRequestSerializer(serializers.ModelSerializer):
    destination_facility_name = serializers.SerializerMethodField()
    driver_name = serializers.CharField(source="driver.full_name", read_only=True)
    is_rated = serializers.SerializerMethodField()
    rating_score = serializers.SerializerMethodField()

    def get_destination_facility_name(self, obj):
        return obj.destination_facility.name if obj.destination_facility_id else None

    def get_is_rated(self, obj):
        return hasattr(obj, "rating")

    def get_rating_score(self, obj):
        return obj.rating.score if hasattr(obj, "rating") else None

    def validate_destination_facility(self, value):
        if value is not None and not value.is_active:
            raise serializers.ValidationError(
                "This facility is no longer accepting trips."
            )
        return value

    class Meta:
        model = Trip
        fields = (
            "id",
            "pickup_address",
            "destination_address",
            "destination_facility",
            "destination_facility_name",
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
            "final_fare",
            "final_fare_breakdown",
            "distance_km",
            "duration_minutes",
            "driver_name",
            "is_rated",
            "rating_score",
            "status",
            "completed_at",
            "created_at",
        )
        read_only_fields = (
            "id",
            "status",
            "created_at",
            "destination_facility_name",
            "final_fare",
            "final_fare_breakdown",
            "distance_km",
            "duration_minutes",
            "driver_name",
            "is_rated",
            "rating_score",
            "completed_at",
        )


class PatientSignupSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    phone_number = serializers.CharField(max_length=32, required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, min_length=6, trim_whitespace=False)
    confirm_password = serializers.CharField(write_only=True, trim_whitespace=False)
    emergency_contact_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    emergency_contact_phone = serializers.CharField(max_length=32, required=False, allow_blank=True)
    mobility_needs = serializers.ChoiceField(
        choices=PatientProfile.MobilityNeeds.choices,
        required=False,
        default=PatientProfile.MobilityNeeds.NONE,
    )
    oxygen_required = serializers.BooleanField(required=False, default=False)
    medical_escort_required = serializers.BooleanField(required=False, default=False)
    iv_drip_required = serializers.BooleanField(required=False, default=False)

    def validate_email(self, value):
        email = value.strip().lower()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("Email is already registered")
        return email

    def validate(self, attrs):
        if attrs["password"] != attrs["confirm_password"]:
            raise serializers.ValidationError({"confirm_password": "Passwords do not match"})
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        validated_data.pop("confirm_password")
        password = validated_data.pop("password")
        emergency_contact_name = validated_data.pop("emergency_contact_name", "")
        emergency_contact_phone = validated_data.pop("emergency_contact_phone", "")
        mobility_needs = validated_data.pop("mobility_needs", PatientProfile.MobilityNeeds.NONE)
        oxygen_required = validated_data.pop("oxygen_required", False)
        medical_escort_required = validated_data.pop("medical_escort_required", False)
        iv_drip_required = validated_data.pop("iv_drip_required", False)
        user = User.objects.create_user(
            password=password,
            status=User.Status.ACTIVE,
            is_active=True,
            is_email_verified=False,
            **validated_data,
        )
        UserRole.objects.get_or_create(user=user, role=get_or_create_patient_role())
        PatientProfile.objects.create(
            user=user,
            emergency_contact_name=emergency_contact_name,
            emergency_contact_phone=emergency_contact_phone,
            mobility_needs=mobility_needs,
            oxygen_required=oxygen_required,
            medical_escort_required=medical_escort_required,
            iv_drip_required=iv_drip_required,
        )
        return user


class GoogleAuthSerializer(serializers.Serializer):
    id_token = serializers.CharField(write_only=True)


class AppleAuthSerializer(serializers.Serializer):
    id_token = serializers.CharField(write_only=True)
    # Apple only ever sends the user's name once, out-of-band, on the very
    # first authorization — the client must capture and forward it here.
    full_name = serializers.CharField(
        max_length=150, required=False, allow_blank=True
    )
