import uuid

from django.conf import settings
from django.db import models


class NotificationPreference(models.Model):
    """Per-user toggle settings for which notification categories to receive."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        related_name="notification_preference",
        on_delete=models.CASCADE,
    )
    ride_updates = models.BooleanField(default=True)
    promotions = models.BooleanField(default=False)
    security_alerts = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f"NotificationPreference({self.user_id})"


class Notification(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="notifications",
        on_delete=models.CASCADE,
    )
    title = models.CharField(max_length=150)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self) -> str:
        return f"Notification({self.recipient_id}, {self.title})"


class Broadcast(models.Model):
    """An admin-sent message fanned out to a group of users. Each recipient
    also gets an individual Notification row (for the bell/WS feed); this
    record just tracks what was sent, to whom, and how many received it."""

    class Audience(models.TextChoices):
        ALL = "all", "All Users"
        DRIVERS = "drivers", "Drivers"
        PATIENTS = "patients", "Patients"
        ADMINS = "admins", "Admins"

    class Channel(models.TextChoices):
        PUSH = "push", "Push"
        SMS = "sms", "SMS"
        EMAIL = "email", "Email"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=150)
    message = models.TextField()
    audience = models.CharField(
        max_length=20, choices=Audience.choices, default=Audience.ALL
    )
    channel = models.CharField(
        max_length=10, choices=Channel.choices, default=Channel.PUSH
    )
    recipient_count = models.PositiveIntegerField(default=0)
    sent_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="broadcasts_sent",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self) -> str:
        return f"Broadcast({self.title}, {self.audience})"
