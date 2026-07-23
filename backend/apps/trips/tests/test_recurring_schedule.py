import pytest
from django.urls import reverse
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.rbac.catalog import sync_role
from apps.rbac.models import UserRole
from apps.trips.models import Trip


def _make_patient():
    user = User.objects.create_user(
        email="patient-recurring@example.com",
        password="StrongPass123",
        full_name="Recurring Patient",
        status=User.Status.ACTIVE,
        is_active=True,
    )
    role = sync_role("PATIENT")
    UserRole.objects.create(user=user, role=role)
    return user


@pytest.mark.django_db
def test_creating_recurring_schedule_books_first_trip_for_dispatch():
    """Before this fix, a RecurringSchedule was a standalone record with no
    Trip ever generated from it — dispatch had nothing to see or assign a
    driver to, since no periodic job exists to turn schedules into trips."""
    patient = _make_patient()
    client = APIClient()
    client.force_authenticate(user=patient)

    response = client.post(
        reverse("recurring-schedule-list"),
        {
            "pickup_address": "123 Pickup St",
            "destination_address": "456 Destination Ave",
            "pickup_time": "07:00:00",
            "frequency": "WEEKLY",
            "days_of_week": [0, 2, 4],
            "start_date": "2026-08-03",
        },
        format="json",
    )

    assert response.status_code == 201, response.data
    schedule_id = response.data["id"]

    trip = Trip.objects.get(recurring_schedule_id=schedule_id)
    assert trip.patient_id == patient.id
    assert trip.status == Trip.Status.REQUESTED
    assert trip.pickup_address == "123 Pickup St"
    assert trip.scheduled_at.date().isoformat() == "2026-08-03"


@pytest.mark.django_db
def test_trip_detail_exposes_recurring_schedule_info_for_admin_and_driver():
    """TripSerializer is shared by admin_web and driver_app — without a nested
    recurring_schedule_detail, neither surface had any way to tell a trip
    apart from a one-off booking."""
    patient = _make_patient()
    client = APIClient()
    client.force_authenticate(user=patient)

    response = client.post(
        reverse("recurring-schedule-list"),
        {
            "pickup_address": "123 Pickup St",
            "destination_address": "456 Destination Ave",
            "pickup_time": "07:00:00",
            "frequency": "WEEKLY",
            "days_of_week": [0, 2, 4],
            "start_date": "2026-08-03",
        },
        format="json",
    )
    trip_id = Trip.objects.get(recurring_schedule_id=response.data["id"]).id

    detail = client.get(reverse("trips-detail", args=[trip_id]))

    assert detail.status_code == 200, detail.data
    recurring = detail.data["recurring_schedule_detail"]
    assert recurring["frequency"] == "WEEKLY"
    assert recurring["frequency_display"] == "Weekly"
    assert recurring["days_of_week"] == [0, 2, 4]


@pytest.mark.django_db
def test_trip_detail_recurring_schedule_detail_is_null_for_one_off_trip():
    patient = _make_patient()
    trip = Trip.objects.create(
        patient=patient,
        pickup_address="1 One-off St",
        destination_address="2 One-off Ave",
        scheduled_at="2026-08-10T07:00:00Z",
        status=Trip.Status.REQUESTED,
    )
    client = APIClient()
    client.force_authenticate(user=patient)

    detail = client.get(reverse("trips-detail", args=[trip.id]))

    assert detail.status_code == 200, detail.data
    assert detail.data["recurring_schedule_detail"] is None
