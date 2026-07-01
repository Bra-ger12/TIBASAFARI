from rest_framework import serializers

from apps.operations.models import Vehicle


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
