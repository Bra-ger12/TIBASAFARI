from rest_framework import serializers


class DashboardStatsSerializer(serializers.Serializer):
    users = serializers.DictField()
    drivers = serializers.DictField()
    patients = serializers.DictField()
    trips = serializers.DictField()

