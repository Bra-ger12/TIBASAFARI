from decimal import Decimal

import pytest
from django.utils import timezone
from rest_framework import exceptions

from apps.accounts.models import User
from apps.drivers.models import DriverDocument, DriverProfile
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


def _make_trip(patient):
    return Trip.objects.create(
        patient=patient,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_latitude=Decimal("-6.7924"),
        pickup_longitude=Decimal("39.2083"),
        destination_latitude=Decimal("-6.8000"),
        destination_longitude=Decimal("39.2900"),
        scheduled_at=timezone.now(),
        status=Trip.Status.REQUESTED,
    )


@pytest.mark.django_db
def test_assign_driver_rejects_driver_with_no_profile():
    patient = _make_user("patient3@example.com")
    driver = _make_user("driver3@example.com")
    trip = _make_trip(patient)

    with pytest.raises(exceptions.ValidationError):
        TripService().assign_driver(trip, driver=driver)


@pytest.mark.django_db
def test_assign_driver_rejects_driver_with_unverified_documents():
    patient = _make_user("patient4@example.com")
    driver = _make_user("driver4@example.com")
    profile = DriverProfile.objects.create(user=driver, license_number="LIC-4")
    DriverDocument.objects.create(
        driver=profile,
        doc_type=DriverDocument.DocType.LICENSE,
        file="driver_documents/2026/01/license.pdf",
        status=DriverDocument.Status.VERIFIED,
    )
    trip = _make_trip(patient)

    with pytest.raises(exceptions.ValidationError):
        TripService().assign_driver(trip, driver=driver)


@pytest.mark.django_db
def test_assign_driver_succeeds_with_all_documents_verified():
    patient = _make_user("patient5@example.com")
    driver = _make_user("driver5@example.com")
    profile = DriverProfile.objects.create(
        user=driver, license_number="LIC-5", is_available=True
    )
    for doc_type in (
        DriverDocument.DocType.LICENSE,
        DriverDocument.DocType.INSURANCE,
        DriverDocument.DocType.VEHICLE_REGISTRATION,
    ):
        DriverDocument.objects.create(
            driver=profile,
            doc_type=doc_type,
            file=f"driver_documents/2026/01/{doc_type}.pdf",
            status=DriverDocument.Status.VERIFIED,
        )
    trip = _make_trip(patient)

    result = TripService().assign_driver(trip, driver=driver)

    assert result.status == Trip.Status.ASSIGNED
    assert result.driver_id == driver.id


def _make_verified_driver(email, license_number):
    driver = _make_user(email)
    profile = DriverProfile.objects.create(
        user=driver, license_number=license_number, is_available=True
    )
    for doc_type in (
        DriverDocument.DocType.LICENSE,
        DriverDocument.DocType.INSURANCE,
        DriverDocument.DocType.VEHICLE_REGISTRATION,
    ):
        DriverDocument.objects.create(
            driver=profile,
            doc_type=doc_type,
            file=f"driver_documents/2026/01/{doc_type}.pdf",
            status=DriverDocument.Status.VERIFIED,
        )
    return driver, profile


@pytest.mark.django_db
def test_assign_driver_rejects_driver_already_unavailable():
    patient = _make_user("patient10@example.com")
    driver, profile = _make_verified_driver("driver10@example.com", "LIC-10")
    profile.is_available = False
    profile.save(update_fields=["is_available"])
    trip = _make_trip(patient)

    with pytest.raises(exceptions.ValidationError):
        TripService().assign_driver(trip, driver=driver)


@pytest.mark.django_db
def test_assign_driver_marks_driver_unavailable():
    patient = _make_user("patient11@example.com")
    driver, profile = _make_verified_driver("driver11@example.com", "LIC-11")
    trip = _make_trip(patient)

    TripService().assign_driver(trip, driver=driver)

    profile.refresh_from_db()
    assert profile.is_available is False


@pytest.mark.django_db
def test_reject_trip_restores_driver_availability():
    patient = _make_user("patient12@example.com")
    driver, profile = _make_verified_driver("driver12@example.com", "LIC-12")
    trip = _make_trip(patient)
    TripService().assign_driver(trip, driver=driver)

    TripService().reject_trip(trip, driver=driver)

    profile.refresh_from_db()
    assert profile.is_available is True


@pytest.mark.django_db
def test_complete_trip_restores_driver_availability():
    patient = _make_user("patient13@example.com")
    driver, profile = _make_verified_driver("driver13@example.com", "LIC-13")
    trip = _make_trip(patient)
    TripService().assign_driver(trip, driver=driver)
    TripService().accept_trip(trip, driver=driver)
    TripService().start_trip(trip, driver=driver)

    TripService().complete_trip(trip, driver=driver, distance_km=5, duration_minutes=10)

    profile.refresh_from_db()
    assert profile.is_available is True


@pytest.mark.django_db
def test_cancel_trip_restores_driver_availability():
    patient = _make_user("patient14@example.com")
    driver, profile = _make_verified_driver("driver14@example.com", "LIC-14")
    trip = _make_trip(patient)
    TripService().assign_driver(trip, driver=driver)

    TripService().cancel_trip(trip, user=patient)

    profile.refresh_from_db()
    assert profile.is_available is True
