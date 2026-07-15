from decimal import Decimal

import pytest
from django.utils import timezone

from apps.accounts.models import User
from apps.patients.serializers import PatientTripRequestSerializer
from apps.trips.models import Trip, TripRating


def _make_user(email, full_name="Test User"):
    return User.objects.create_user(
        email=email,
        password="StrongPass123",
        full_name=full_name,
        status=User.Status.ACTIVE,
        is_active=True,
    )


@pytest.mark.django_db
def test_serializer_exposes_completed_trip_details_and_rating():
    """Regression test: patient_app's history screen reads duration_minutes,
    distance_km, driver_name, is_rated, and rating_score directly off the
    /patients/trip-requests/ response — this serializer used to omit all of
    them, so "Hours Saved" always computed 0 and the rating star display
    was always blank even for already-rated trips."""
    patient = _make_user("patient20@example.com", "Test Patient")
    driver = _make_user("driver20@example.com", "Test Driver")
    trip = Trip.objects.create(
        patient=patient,
        driver=driver,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        scheduled_at=timezone.now(),
        status=Trip.Status.COMPLETED,
        completed_at=timezone.now(),
        distance_km=Decimal("12.500"),
        duration_minutes=25,
        final_fare=Decimal("15000.00"),
    )
    TripRating.objects.create(trip=trip, patient=patient, score=5, comment="Great ride")

    data = PatientTripRequestSerializer(trip).data

    assert data["duration_minutes"] == 25
    assert Decimal(str(data["distance_km"])) == Decimal("12.500")
    assert Decimal(str(data["final_fare"])) == Decimal("15000.00")
    assert data["driver_name"] == "Test Driver"
    assert data["is_rated"] is True
    assert data["rating_score"] == 5
    assert data["completed_at"] is not None


@pytest.mark.django_db
def test_serializer_handles_unassigned_and_unrated_trip():
    patient = _make_user("patient21@example.com", "Test Patient")
    trip = Trip.objects.create(
        patient=patient,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        scheduled_at=timezone.now(),
        status=Trip.Status.REQUESTED,
    )

    data = PatientTripRequestSerializer(trip).data

    # DRF omits a read-only dotted-source field entirely (rather than
    # emitting null) when a step in the chain is None — .get() reflects
    # what the Flutter side actually sees either way (a missing key and an
    # explicit null both deserialize to `null` in a Dart Map).
    assert data.get("driver_name") is None
    assert data["is_rated"] is False
    assert data["rating_score"] is None
