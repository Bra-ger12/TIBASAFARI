from rest_framework import serializers

from apps.notifications.models import Notification, NotificationPreference


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationPreference
        fields = ("ride_updates", "promotions", "security_alerts", "updated_at")
        read_only_fields = ("updated_at",)


class NotificationSerializer(serializers.ModelSerializer):
    recipient_email = serializers.EmailField(source="recipient.email", read_only=True)

    class Meta:
        model = Notification
        fields = (
            "id",
            "recipient",
            "recipient_email",
            "title",
            "message",
            "is_read",
            "metadata",
            "created_at",
            "read_at",
        )
        read_only_fields = ("id", "recipient_email", "created_at", "read_at")
