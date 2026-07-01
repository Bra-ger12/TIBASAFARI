import django.db.models.deletion
import uuid
from decimal import Decimal

from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ("trips", "0001_initial"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Invoice",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("invoice_number", models.CharField(editable=False, max_length=30, unique=True)),
                ("trip", models.OneToOneField(on_delete=django.db.models.deletion.PROTECT, related_name="invoice", to="trips.trip")),
                ("patient", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="invoices", to=settings.AUTH_USER_MODEL)),
                ("base_fare", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("distance_km", models.DecimalField(decimal_places=3, default=Decimal("0.000"), max_digits=8)),
                ("distance_charge", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("duration_minutes", models.PositiveIntegerField(default=0)),
                ("time_charge", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("wheelchair_surcharge", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("discount", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("subtotal", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("tax_rate", models.DecimalField(decimal_places=4, default=Decimal("0.0000"), max_digits=5)),
                ("tax_amount", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("total_amount", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("amount_paid", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("amount_due", models.DecimalField(decimal_places=2, default=Decimal("0.00"), max_digits=10)),
                ("status", models.CharField(choices=[("DRAFT","Draft"),("ISSUED","Issued"),("PAID","Paid"),("PARTIALLY_PAID","Partially Paid"),("OVERDUE","Overdue"),("CANCELLED","Cancelled"),("REFUNDED","Refunded")], default="DRAFT", max_length=20)),
                ("notes", models.TextField(blank=True)),
                ("due_date", models.DateField(blank=True, null=True)),
                ("issued_at", models.DateTimeField(blank=True, null=True)),
                ("paid_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ("-created_at",)},
        ),
        migrations.CreateModel(
            name="Payment",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("invoice", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="payments", to="billing.invoice")),
                ("amount", models.DecimalField(decimal_places=2, max_digits=10)),
                ("method", models.CharField(choices=[("CASH","Cash"),("MOBILE_MONEY","Mobile Money"),("CARD","Card"),("INSURANCE","Insurance"),("BANK_TRANSFER","Bank Transfer"),("WAIVED","Waived")], max_length=20)),
                ("status", models.CharField(choices=[("PENDING","Pending"),("COMPLETED","Completed"),("FAILED","Failed"),("REFUNDED","Refunded")], default="PENDING", max_length=20)),
                ("reference", models.CharField(blank=True, max_length=120)),
                ("notes", models.TextField(blank=True)),
                ("recorded_by", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="recorded_payments", to=settings.AUTH_USER_MODEL)),
                ("processed_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={"ordering": ("-created_at",)},
        ),
        migrations.AddIndex(
            model_name="invoice",
            index=models.Index(fields=["patient", "status"], name="billing_inv_patient_status_idx"),
        ),
        migrations.AddIndex(
            model_name="invoice",
            index=models.Index(fields=["status", "due_date"], name="billing_inv_status_due_idx"),
        ),
    ]
