import uuid

from django.conf import settings
from django.db import models

from apps.operations.models import Vehicle


class DriverProfile(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        related_name="driver_profile",
        on_delete=models.CASCADE,
    )
    license_number = models.CharField(max_length=80, unique=True)
    vehicle = models.ForeignKey(
        Vehicle,
        related_name="drivers",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    is_available = models.BooleanField(default=False)
    current_latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
    )
    current_longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
    )
    last_location_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("user__email",)

    def __str__(self) -> str:
        return f"DriverProfile({self.user.email})"


class DriverDocument(models.Model):
    """Compliance documents (license, insurance, vehicle registration)
    uploaded by a driver for staff verification."""

    class DocType(models.TextChoices):
        LICENSE = "LICENSE", "Driver's License"
        INSURANCE = "INSURANCE", "Vehicle Insurance"
        VEHICLE_REGISTRATION = "VEHICLE_REGISTRATION", "Vehicle Registration"

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending Review"
        VERIFIED = "VERIFIED", "Verified"
        REJECTED = "REJECTED", "Rejected"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    driver = models.ForeignKey(
        DriverProfile,
        related_name="documents",
        on_delete=models.CASCADE,
    )
    doc_type = models.CharField(max_length=30, choices=DocType.choices)
    file = models.FileField(upload_to="driver_documents/%Y/%m/")
    expiry_date = models.DateField(null=True, blank=True)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )
    rejection_reason = models.TextField(blank=True)
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="reviewed_driver_documents",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-uploaded_at",)

    def __str__(self) -> str:
        return f"DriverDocument({self.driver_id}, {self.doc_type}, {self.status})"

