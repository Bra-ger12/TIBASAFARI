from decimal import Decimal

import pytest
from django.utils import timezone

from apps.accounts.models import User
from apps.trips.models import Trip
from apps.trips.services import TripService


def _make_user(email, full_name="Test User"):
    return User.objects.create_user(
        email=email,
        password="StrongPass123",
        full_name=full_name,
        status=User.Status.ACTIVE,
        is_active=True,
    )


@pytest.mark.django_db
def test_complete_trip_auto_creates_invoice_matching_final_fare():
    """A completed trip must always end up with a payable invoice — before
    this fix, no invoice was ever created unless a staff member manually
    hit the (unreachable-from-any-UI) generate endpoint."""
    patient = _make_user("patient@example.com", "Test Patient")
    driver = _make_user("driver@example.com", "Test Driver")

    trip = Trip.objects.create(
        patient=patient,
        driver=driver,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_latitude=Decimal("-6.7924"),
        pickup_longitude=Decimal("39.2083"),
        destination_latitude=Decimal("-6.8000"),
        destination_longitude=Decimal("39.2900"),
        scheduled_at=timezone.now(),
        status=Trip.Status.EN_ROUTE,
    )

    assert not hasattr(trip, "invoice")

    TripService().complete_trip(trip, driver=driver, distance_km=10, duration_minutes=20)

    trip.refresh_from_db()
    assert trip.status == Trip.Status.COMPLETED
    assert trip.final_fare is not None

    invoice = trip.invoice
    assert invoice.patient_id == patient.id
    assert invoice.total_amount == trip.final_fare
    assert invoice.amount_due == trip.final_fare
    assert invoice.status == "ISSUED"


@pytest.mark.django_db
def test_complete_trip_is_idempotent_for_invoicing():
    """Completing (or re-invoicing) a trip that already has an invoice must
    never create a second one — Invoice.trip is a OneToOneField, but the
    service should short-circuit before hitting that constraint."""
    from apps.billing.services import InvoiceService

    patient = _make_user("patient2@example.com", "Test Patient 2")
    driver = _make_user("driver2@example.com", "Test Driver 2")
    trip = Trip.objects.create(
        patient=patient,
        driver=driver,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_latitude=Decimal("-6.7924"),
        pickup_longitude=Decimal("39.2083"),
        destination_latitude=Decimal("-6.8000"),
        destination_longitude=Decimal("39.2900"),
        scheduled_at=timezone.now(),
        status=Trip.Status.EN_ROUTE,
    )

    TripService().complete_trip(trip, driver=driver, distance_km=10, duration_minutes=20)
    trip.refresh_from_db()
    first_invoice_id = trip.invoice.id

    second = InvoiceService().create_for_trip(trip)
    assert second.id == first_invoice_id
