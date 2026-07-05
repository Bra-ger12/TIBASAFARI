from rest_framework import serializers

from apps.facilities.models import HealthFacility


class HealthFacilitySerializer(serializers.ModelSerializer):
    facility_type_display = serializers.CharField(
        source="get_facility_type_display", read_only=True
    )

    class Meta:
        model = HealthFacility
        fields = (
            "id",
            "name",
            "facility_type",
            "facility_type_display",
            "region",
            "district",
            "latitude",
            "longitude",
            "is_active",
        )
        read_only_fields = fields


class HealthFacilityNearbySerializer(HealthFacilitySerializer):
    distance_km = serializers.FloatField(read_only=True)

    class Meta(HealthFacilitySerializer.Meta):
        fields = HealthFacilitySerializer.Meta.fields + ("distance_km",)
        read_only_fields = fields
