from django.db import transaction
from rest_framework import serializers

from apps.accounts.models import User
from apps.patients.models import PatientProfile
from apps.rbac.models import Permission, Role, UserRole
from apps.trips.models import Trip


class PatientProfileSerializer(serializers.ModelSerializer):
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_full_name = serializers.CharField(source="user.full_name", read_only=True)
    user_phone = serializers.CharField(source="user.phone", read_only=True)
    trips_count = serializers.SerializerMethodField()

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
            "default_pickup_address",
            "trips_count",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "user_email",
            "user_full_name",
            "user_phone",
            "trips_count",
            "created_at",
            "updated_at",
        )

    def get_trips_count(self, obj):
        from apps.trips.models import Trip
        return Trip.objects.filter(patient=obj.user).count()

    def validate_user(self, value):
        queryset = PatientProfile.objects.filter(user=value)
        if self.instance:
            queryset = queryset.exclude(pk=self.instance.pk)
        if queryset.exists():
            raise serializers.ValidationError("Patient profile already exists")
        return value


class PatientTripRequestSerializer(serializers.ModelSerializer):
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
            "status",
            "created_at",
        )
        read_only_fields = ("id", "status", "created_at")


class PatientSignupSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    phone_number = serializers.CharField(max_length=32, required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, min_length=6, trim_whitespace=False)
    confirm_password = serializers.CharField(write_only=True, trim_whitespace=False)
    emergency_contact_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    emergency_contact_phone = serializers.CharField(max_length=32, required=False, allow_blank=True)

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
        user = User.objects.create_user(
            password=password,
            status=User.Status.ACTIVE,
            is_active=True,
            **validated_data,
        )
        UserRole.objects.get_or_create(user=user, role=self._patient_role())
        PatientProfile.objects.create(
            user=user,
            emergency_contact_name=emergency_contact_name,
            emergency_contact_phone=emergency_contact_phone,
        )
        return user

    def _patient_role(self):
        role, _ = Role.objects.get_or_create(
            code="PATIENT",
            defaults={"name": "Patient", "description": "Patient user"},
        )
        permission_codes = {
            "create_trip": "Create trip",
            "view_own_trips": "View own trips",
            "view_own_profile": "View own profile",
            "view_notifications": "View notifications",
        }
        for code, name in permission_codes.items():
            perm, _ = Permission.objects.get_or_create(code=code, defaults={"name": name})
            role.permissions.add(perm)
        return role
