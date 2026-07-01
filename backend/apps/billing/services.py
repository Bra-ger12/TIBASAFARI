"""
Fare calculation and invoice generation services.

Fare formula:
  base_fare
  + distance_km * FARE_PER_KM
  + duration_minutes * FARE_PER_MINUTE
  + wheelchair_surcharge (if applicable)
  - discount
  = subtotal → apply tax → total_amount
  minimum: FARE_MINIMUM
"""
from decimal import ROUND_HALF_UP, Decimal

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.conf import settings
from django.utils import timezone
from rest_framework import exceptions

from apps.billing.models import Invoice, Payment
from apps.trips.models import Trip


def _d(value) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _notify(recipient, title: str, message: str, metadata: dict = None):
    """Create a DB notification and push it via WebSocket (best-effort)."""
    from apps.notifications.models import Notification

    notif = Notification.objects.create(
        recipient=recipient,
        title=title,
        message=message,
        metadata=metadata or {},
    )
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"notifications_{recipient.id}",
            {
                "type": "notification.push",
                "id": str(notif.id),
                "title": notif.title,
                "message": notif.message,
                "metadata": notif.metadata,
                "created_at": notif.created_at.isoformat(),
            },
        )
    except Exception:
        pass


class FareCalculator:
    def __init__(self):
        self.base_rate = _d(settings.FARE_BASE_RATE)
        self.per_km = _d(settings.FARE_PER_KM)
        self.per_minute = _d(settings.FARE_PER_MINUTE)
        self.minimum = _d(settings.FARE_MINIMUM)
        self.wheelchair_surcharge = _d(settings.FARE_WHEELCHAIR_SURCHARGE)

    def calculate(
        self,
        distance_km: float,
        duration_minutes: int,
        *,
        wheelchair: bool = False,
        discount: Decimal = Decimal("0.00"),
        tax_rate: Decimal = Decimal("0.00"),
    ) -> dict:
        distance_km = _d(distance_km)
        duration_minutes = int(duration_minutes)

        base_fare = self.base_rate
        distance_charge = (distance_km * self.per_km).quantize(
            Decimal("0.01"), rounding=ROUND_HALF_UP
        )
        time_charge = (_d(duration_minutes) * self.per_minute).quantize(
            Decimal("0.01"), rounding=ROUND_HALF_UP
        )
        w_surcharge = self.wheelchair_surcharge if wheelchair else Decimal("0.00")

        subtotal = base_fare + distance_charge + time_charge + w_surcharge - _d(discount)
        subtotal = max(subtotal, self.minimum)

        tax_rate = _d(tax_rate)
        tax_amount = (subtotal * tax_rate).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        total = subtotal + tax_amount

        return {
            "base_fare": base_fare,
            "distance_km": distance_km,
            "distance_charge": distance_charge,
            "duration_minutes": duration_minutes,
            "time_charge": time_charge,
            "wheelchair_surcharge": w_surcharge,
            "discount": _d(discount),
            "subtotal": subtotal,
            "tax_rate": tax_rate,
            "tax_amount": tax_amount,
            "total_amount": total,
            "amount_due": total,
            "amount_paid": Decimal("0.00"),
        }


class InvoiceService:
    calculator = FareCalculator()

    def create_for_trip(
        self,
        trip: Trip,
        distance_km: float = 0.0,
        duration_minutes: int = 0,
        discount: Decimal = Decimal("0.00"),
        tax_rate: Decimal = Decimal("0.00"),
    ) -> Invoice:
        if hasattr(trip, "invoice"):
            return trip.invoice

        wheelchair = "wheelchair" in (trip.special_requirements or "").lower()
        fare = self.calculator.calculate(
            distance_km,
            duration_minutes,
            wheelchair=wheelchair,
            discount=discount,
            tax_rate=tax_rate,
        )

        invoice = Invoice.objects.create(
            trip=trip,
            patient=trip.patient,
            status=Invoice.Status.ISSUED,
            issued_at=timezone.now(),
            **fare,
        )
        return invoice

    def submit_payment(
        self,
        invoice: Invoice,
        amount: Decimal,
        method: str,
        *,
        reference: str = "",
        notes: str = "",
    ) -> Payment:
        """Patient self-reports a payment made outside the app. Creates a
        PENDING Payment only — the invoice balance is untouched until staff
        verify and confirm it via record_payment()."""
        return Payment.objects.create(
            invoice=invoice,
            amount=amount,
            method=method,
            status=Payment.Status.PENDING,
            reference=reference,
            notes=notes,
        )

    def record_payment(
        self,
        invoice: Invoice,
        amount: Decimal,
        method: str,
        *,
        reference: str = "",
        recorded_by=None,
    ) -> Payment:
        payment = Payment.objects.create(
            invoice=invoice,
            amount=amount,
            method=method,
            status=Payment.Status.COMPLETED,
            reference=reference,
            recorded_by=recorded_by,
            processed_at=timezone.now(),
        )
        invoice.amount_paid += amount
        invoice.amount_due = max(Decimal("0.00"), invoice.total_amount - invoice.amount_paid)
        if invoice.amount_due == Decimal("0.00"):
            invoice.status = Invoice.Status.PAID
            invoice.paid_at = timezone.now()
        else:
            invoice.status = Invoice.Status.PARTIALLY_PAID
        invoice.save(update_fields=["amount_paid", "amount_due", "status", "paid_at", "updated_at"])
        return payment

    def verify_payment(self, payment: Payment, *, verified_by) -> Payment:
        """Staff confirms a patient's self-reported (submit_payment) payment —
        marks that same Payment row COMPLETED and applies it to the invoice
        balance, instead of record_payment's behaviour of creating a new one."""
        if payment.status != Payment.Status.PENDING:
            raise exceptions.ValidationError("Only pending payments can be verified")

        payment.status = Payment.Status.COMPLETED
        payment.recorded_by = verified_by
        payment.processed_at = timezone.now()
        payment.save(update_fields=["status", "recorded_by", "processed_at"])

        invoice = payment.invoice
        invoice.amount_paid += payment.amount
        invoice.amount_due = max(Decimal("0.00"), invoice.total_amount - invoice.amount_paid)
        if invoice.amount_due == Decimal("0.00"):
            invoice.status = Invoice.Status.PAID
            invoice.paid_at = timezone.now()
        else:
            invoice.status = Invoice.Status.PARTIALLY_PAID
        invoice.save(update_fields=["amount_paid", "amount_due", "status", "paid_at", "updated_at"])

        _notify(
            invoice.patient,
            "Payment Verified",
            f"Your payment of {payment.amount} for invoice {invoice.invoice_number} has been verified.",
            {"invoice_id": str(invoice.id), "payment_id": str(payment.id)},
        )
        return payment

    def reject_payment(self, payment: Payment, *, reason: str = "") -> Payment:
        if payment.status != Payment.Status.PENDING:
            raise exceptions.ValidationError("Only pending payments can be rejected")

        payment.status = Payment.Status.FAILED
        if reason:
            payment.notes = f"{payment.notes}\n[Rejected: {reason}]".strip()
        payment.save(update_fields=["status", "notes"])

        invoice = payment.invoice
        _notify(
            invoice.patient,
            "Payment Could Not Be Verified",
            (
                f"Your submitted payment of {payment.amount} for invoice "
                f"{invoice.invoice_number} could not be verified"
                + (f": {reason}" if reason else ".")
            ),
            {"invoice_id": str(invoice.id), "payment_id": str(payment.id)},
        )
        return payment
