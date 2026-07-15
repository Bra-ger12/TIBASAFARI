from decimal import Decimal

import pytest
from django.utils import timezone

from apps.accounts.models import User
from apps.billing.models import Invoice, Payment
from apps.billing.services import InvoiceService
from apps.trips.models import Trip


def _make_user(email, full_name="Test User"):
    return User.objects.create_user(
        email=email,
        password="StrongPass123",
        full_name=full_name,
        status=User.Status.ACTIVE,
        is_active=True,
    )


def _make_invoice(patient, total=Decimal("100.00")):
    trip = Trip.objects.create(
        patient=patient,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_latitude=Decimal("-6.7924"),
        pickup_longitude=Decimal("39.2083"),
        destination_latitude=Decimal("-6.8000"),
        destination_longitude=Decimal("39.2900"),
        scheduled_at=timezone.now(),
        status=Trip.Status.COMPLETED,
    )
    return Invoice.objects.create(
        trip=trip,
        patient=patient,
        status=Invoice.Status.ISSUED,
        issued_at=timezone.now(),
        total_amount=total,
        amount_due=total,
    )


@pytest.mark.django_db
def test_record_payment_updates_balance_and_marks_paid():
    patient = _make_user("patient6@example.com")
    invoice = _make_invoice(patient, total=Decimal("100.00"))

    payment = InvoiceService().record_payment(
        invoice, Decimal("100.00"), Payment.Method.CASH
    )

    invoice.refresh_from_db()
    assert payment.status == Payment.Status.COMPLETED
    assert invoice.amount_paid == Decimal("100.00")
    assert invoice.amount_due == Decimal("0.00")
    assert invoice.status == Invoice.Status.PAID


@pytest.mark.django_db
def test_record_payment_two_partial_payments_both_apply():
    """Regression test: record_payment used to read/modify/write
    invoice.amount_paid without locking the row, so two concurrent partial
    payments could race and one would silently overwrite the other's
    contribution. Sequential partial payments (the case this test can
    exercise without real threads) must both land correctly."""
    patient = _make_user("patient7@example.com")
    invoice = _make_invoice(patient, total=Decimal("100.00"))

    InvoiceService().record_payment(invoice, Decimal("40.00"), Payment.Method.CASH)
    invoice.refresh_from_db()
    InvoiceService().record_payment(invoice, Decimal("60.00"), Payment.Method.CASH)

    invoice.refresh_from_db()
    assert invoice.amount_paid == Decimal("100.00")
    assert invoice.amount_due == Decimal("0.00")
    assert invoice.status == Invoice.Status.PAID
    assert invoice.payments.count() == 2


@pytest.mark.django_db
def test_verify_payment_applies_pending_payment_to_balance():
    patient = _make_user("patient8@example.com")
    staff = _make_user("staff1@example.com", "Staff Member")
    invoice = _make_invoice(patient, total=Decimal("50.00"))
    payment = Payment.objects.create(
        invoice=invoice,
        amount=Decimal("50.00"),
        method=Payment.Method.MOBILE_MONEY,
        status=Payment.Status.PENDING,
    )

    InvoiceService().verify_payment(payment, verified_by=staff)

    payment.refresh_from_db()
    invoice.refresh_from_db()
    assert payment.status == Payment.Status.COMPLETED
    assert invoice.amount_paid == Decimal("50.00")
    assert invoice.status == Invoice.Status.PAID


@pytest.mark.django_db
def test_verify_payment_rejects_already_processed_payment():
    patient = _make_user("patient9@example.com")
    staff = _make_user("staff2@example.com", "Staff Member")
    invoice = _make_invoice(patient, total=Decimal("50.00"))
    payment = Payment.objects.create(
        invoice=invoice,
        amount=Decimal("50.00"),
        method=Payment.Method.MOBILE_MONEY,
        status=Payment.Status.COMPLETED,
    )

    with pytest.raises(Exception):
        InvoiceService().verify_payment(payment, verified_by=staff)
