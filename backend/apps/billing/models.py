import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models

from apps.trips.models import Trip


class Invoice(models.Model):
    class Status(models.TextChoices):
        DRAFT = "DRAFT", "Draft"
        ISSUED = "ISSUED", "Issued"
        PAID = "PAID", "Paid"
        PARTIALLY_PAID = "PARTIALLY_PAID", "Partially Paid"
        OVERDUE = "OVERDUE", "Overdue"
        CANCELLED = "CANCELLED", "Cancelled"
        REFUNDED = "REFUNDED", "Refunded"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    invoice_number = models.CharField(max_length=30, unique=True, editable=False)
    trip = models.OneToOneField(Trip, related_name="invoice", on_delete=models.PROTECT)
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="invoices",
        on_delete=models.PROTECT,
    )

    # Line items
    base_fare = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    distance_km = models.DecimalField(max_digits=8, decimal_places=3, default=Decimal("0.000"))
    distance_charge = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    duration_minutes = models.PositiveIntegerField(default=0)
    time_charge = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    wheelchair_surcharge = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    discount = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    subtotal = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    tax_rate = models.DecimalField(max_digits=5, decimal_places=4, default=Decimal("0.0000"))
    tax_amount = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    total_amount = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    amount_paid = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    amount_due = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))

    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    notes = models.TextField(blank=True)
    due_date = models.DateField(null=True, blank=True)
    issued_at = models.DateTimeField(null=True, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=("patient", "status")),
            models.Index(fields=("status", "due_date")),
        ]

    def __str__(self):
        return f"Invoice({self.invoice_number}, {self.status})"

    def save(self, *args, **kwargs):
        if not self.invoice_number:
            self.invoice_number = self._generate_invoice_number()
        super().save(*args, **kwargs)

    @staticmethod
    def _generate_invoice_number():
        import datetime
        from django.db.models import Max

        year = datetime.date.today().year
        last = Invoice.objects.filter(
            invoice_number__startswith=f"TS-{year}-"
        ).aggregate(Max("invoice_number"))["invoice_number__max"]
        if last:
            seq = int(last.split("-")[-1]) + 1
        else:
            seq = 1
        return f"TS-{year}-{seq:06d}"


class SavedPaymentMethod(models.Model):
    """A patient-linked payment method shown in their app. No real payment
    gateway is integrated yet — this only stores a masked display label so
    the patient can pick a preferred method when self-reporting a payment."""

    class MethodType(models.TextChoices):
        MOBILE_MONEY = "MOBILE_MONEY", "Mobile Money"
        CARD = "CARD", "Card"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="saved_payment_methods",
        on_delete=models.CASCADE,
    )
    method_type = models.CharField(max_length=20, choices=MethodType.choices)
    label = models.CharField(max_length=100)
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-is_default", "-created_at")

    def __str__(self) -> str:
        return f"SavedPaymentMethod({self.patient_id}, {self.label})"


class Payment(models.Model):
    class Method(models.TextChoices):
        CASH = "CASH", "Cash"
        MOBILE_MONEY = "MOBILE_MONEY", "Mobile Money"
        CARD = "CARD", "Card"
        INSURANCE = "INSURANCE", "Insurance"
        BANK_TRANSFER = "BANK_TRANSFER", "Bank Transfer"
        WAIVED = "WAIVED", "Waived"

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        COMPLETED = "COMPLETED", "Completed"
        FAILED = "FAILED", "Failed"
        REFUNDED = "REFUNDED", "Refunded"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    invoice = models.ForeignKey(Invoice, related_name="payments", on_delete=models.PROTECT)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    method = models.CharField(max_length=20, choices=Method.choices)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    reference = models.CharField(max_length=120, blank=True)
    notes = models.TextField(blank=True)
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="recorded_payments",
    )
    processed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"Payment({self.invoice.invoice_number}, {self.amount}, {self.status})"


class PricingConfig(models.Model):
    """DB-configurable pricing parameters for the hybrid fare estimator
    (apps.billing.services.FareEstimator) — lets staff tune pricing without
    a deploy. See get_active()."""

    class ServiceType(models.TextChoices):
        BASIC = "basic", "Basic"
        WHEELCHAIR = "wheelchair", "Wheelchair"
        MEDICAL_EQUIPMENT = "medical_equipment", "Medical Equipment"

    name = models.CharField(max_length=100, default="default")
    is_active = models.BooleanField(default=True)

    base_fare = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal("2.50"))
    per_km_rate = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal("1.20"))
    per_minute_wait_rate = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal("0.25"))
    minimum_fare = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal("8.00"))

    # Service-type multipliers, applied to (base + distance + waiting).
    basic_multiplier = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal("1.00"))
    wheelchair_multiplier = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal("1.25"))
    medical_equipment_multiplier = models.DecimalField(
        max_digits=4, decimal_places=2, default=Decimal("1.50")
    )

    # Surcharges — a percentage of the post-multiplier subtotal.
    peak_hour_surcharge_pct = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal("0.20"))
    urban_zone_surcharge_pct = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal("0.10"))

    # Urban zone = a Haversine-radius circle around this center point.
    # Defaults to Dar es Salaam city center.
    urban_zone_center_lat = models.DecimalField(max_digits=9, decimal_places=6, default=Decimal("-6.792400"))
    urban_zone_center_lng = models.DecimalField(max_digits=9, decimal_places=6, default=Decimal("39.208300"))
    urban_zone_radius_km = models.DecimalField(max_digits=6, decimal_places=2, default=Decimal("5.00"))

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-is_active", "-updated_at")

    def __str__(self) -> str:
        return f"PricingConfig({self.name}, active={self.is_active})"

    def multiplier_for(self, service_type: str) -> Decimal:
        return {
            self.ServiceType.BASIC: self.basic_multiplier,
            self.ServiceType.WHEELCHAIR: self.wheelchair_multiplier,
            self.ServiceType.MEDICAL_EQUIPMENT: self.medical_equipment_multiplier,
        }.get(service_type, self.basic_multiplier)

    @classmethod
    def get_active(cls) -> "PricingConfig":
        config = cls.objects.filter(is_active=True).order_by("-updated_at").first()
        if config is None:
            config = cls.objects.create(name="default")
        return config
