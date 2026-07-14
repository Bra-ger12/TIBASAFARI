from rest_framework import serializers

from apps.operations.models import Vehicle, VehicleExpense


class VehicleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vehicle
        fields = (
            "id",
            "registration_number",
            "make",
            "model",
            "year",
            "capacity",
            "has_wheelchair_access",
            "status",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def validate_year(self, value):
        if value < 1990:
            raise serializers.ValidationError("Vehicle year is too old")
        return value


class VehicleExpenseSerializer(serializers.ModelSerializer):
    vehicle_registration = serializers.CharField(
        source="vehicle.registration_number", read_only=True
    )
    recorded_by_name = serializers.CharField(
        source="recorded_by.full_name", read_only=True, default=""
    )

    class Meta:
        model = VehicleExpense
        fields = (
            "id",
            "vehicle",
            "vehicle_registration",
            "category",
            "description",
            "amount",
            "incurred_at",
            "recorded_by",
            "recorded_by_name",
            "created_at",
        )
        read_only_fields = ("id", "recorded_by", "recorded_by_name", "created_at")
