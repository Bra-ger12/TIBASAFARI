import uuid

from django.conf import settings
from django.db import models


class Vehicle(models.Model):
    class Status(models.TextChoices):
        AVAILABLE = "available", "Available"
        IN_SERVICE = "in_service", "In Service"
        MAINTENANCE = "maintenance", "Maintenance"
        INACTIVE = "inactive", "Inactive"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    registration_number = models.CharField(max_length=32, unique=True)
    make = models.CharField(max_length=80)
    model = models.CharField(max_length=80)
    year = models.PositiveIntegerField()
    capacity = models.PositiveIntegerField(default=4)
    has_wheelchair_access = models.BooleanField(default=False)
    status = models.CharField(
        max_length=24,
        choices=Status.choices,
        default=Status.AVAILABLE,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("registration_number",)

    def __str__(self) -> str:
        return self.registration_number


class VehicleExpense(models.Model):
    class Category(models.TextChoices):
        MAINTENANCE = "MAINTENANCE", "Maintenance"
        REPAIR = "REPAIR", "Repair"
        INSURANCE = "INSURANCE", "Insurance"
        OTHER = "OTHER", "Other"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    vehicle = models.ForeignKey(
        Vehicle,
        related_name="expenses",
        on_delete=models.CASCADE,
    )
    category = models.CharField(
        max_length=20,
        choices=Category.choices,
        default=Category.MAINTENANCE,
    )
    description = models.CharField(max_length=255, blank=True)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    incurred_at = models.DateField()
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="recorded_vehicle_expenses",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-incurred_at", "-created_at")

    def __str__(self) -> str:
        return f"{self.vehicle.registration_number} — {self.category} ({self.amount})"
