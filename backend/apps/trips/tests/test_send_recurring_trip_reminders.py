from datetime import time, timedelta
from io import StringIO

import pytest
from django.core.management import call_command
from django.utils import timezone

from apps.accounts.models import User
from apps.notifications.models import Notification
from apps.trips.models import RecurringSchedule, Trip


def _make_user(email):
    return User.objects.create_user(
        email=email,
        password="StrongPass123",
        full_name="Reminder Test User",
        status=User.Status.ACTIVE,
        is_active=True,
    )


def _make_schedule(patient):
    return RecurringSchedule.objects.create(
        patient=patient,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_time=time(7, 0),
        frequency=RecurringSchedule.Frequency.DAILY,
        start_date=timezone.localdate(),
    )


def _make_trip(*, patient, driver=None, schedule=None, scheduled_at=None, status=Trip.Status.ASSIGNED):
    return Trip.objects.create(
        patient=patient,
        driver=driver,
        recurring_schedule=schedule,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        scheduled_at=scheduled_at or timezone.now() + timedelta(days=1),
        status=status,
    )


def _run_command():
    out = StringIO()
    call_command("send_recurring_trip_reminders", stdout=out)
    return out.getvalue()


@pytest.mark.django_db
def test_reminds_driver_for_recurring_trip_due_tomorrow():
    patient = _make_user("patient-reminder1@example.com")
    driver = _make_user("driver-reminder1@example.com")
    schedule = _make_schedule(patient)
    tomorrow = timezone.now() + timedelta(days=1)
    trip = _make_trip(patient=patient, driver=driver, schedule=schedule, scheduled_at=tomorrow)

    _run_command()

    trip.refresh_from_db()
    assert trip.driver_reminder_sent_at is not None
    assert Notification.objects.filter(recipient=driver, metadata__trip_id=str(trip.id)).exists()


@pytest.mark.django_db
def test_does_not_remind_twice():
    patient = _make_user("patient-reminder2@example.com")
    driver = _make_user("driver-reminder2@example.com")
    schedule = _make_schedule(patient)
    tomorrow = timezone.now() + timedelta(days=1)
    trip = _make_trip(patient=patient, driver=driver, schedule=schedule, scheduled_at=tomorrow)

    _run_command()
    _run_command()

    assert Notification.objects.filter(recipient=driver, metadata__trip_id=str(trip.id)).count() == 1


@pytest.mark.django_db
def test_skips_trip_with_no_driver_assigned():
    patient = _make_user("patient-reminder3@example.com")
    schedule = _make_schedule(patient)
    tomorrow = timezone.now() + timedelta(days=1)
    trip = _make_trip(patient=patient, driver=None, schedule=schedule, scheduled_at=tomorrow, status=Trip.Status.REQUESTED)

    _run_command()

    trip.refresh_from_db()
    assert trip.driver_reminder_sent_at is None


@pytest.mark.django_db
def test_skips_non_recurring_trip():
    patient = _make_user("patient-reminder4@example.com")
    driver = _make_user("driver-reminder4@example.com")
    tomorrow = timezone.now() + timedelta(days=1)
    trip = _make_trip(patient=patient, driver=driver, schedule=None, scheduled_at=tomorrow)

    _run_command()

    trip.refresh_from_db()
    assert trip.driver_reminder_sent_at is None


@pytest.mark.django_db
def test_skips_completed_and_cancelled_trips():
    patient = _make_user("patient-reminder5@example.com")
    driver = _make_user("driver-reminder5@example.com")
    schedule = _make_schedule(patient)
    tomorrow = timezone.now() + timedelta(days=1)
    completed = _make_trip(
        patient=patient, driver=driver, schedule=schedule, scheduled_at=tomorrow, status=Trip.Status.COMPLETED
    )
    cancelled = _make_trip(
        patient=patient, driver=driver, schedule=schedule, scheduled_at=tomorrow, status=Trip.Status.CANCELLED
    )

    _run_command()

    completed.refresh_from_db()
    cancelled.refresh_from_db()
    assert completed.driver_reminder_sent_at is None
    assert cancelled.driver_reminder_sent_at is None


@pytest.mark.django_db
def test_skips_trip_not_scheduled_for_tomorrow():
    patient = _make_user("patient-reminder6@example.com")
    driver = _make_user("driver-reminder6@example.com")
    schedule = _make_schedule(patient)
    today = timezone.now()
    in_two_days = timezone.now() + timedelta(days=2)
    trip_today = _make_trip(patient=patient, driver=driver, schedule=schedule, scheduled_at=today)
    trip_later = _make_trip(patient=patient, driver=driver, schedule=schedule, scheduled_at=in_two_days)

    _run_command()

    trip_today.refresh_from_db()
    trip_later.refresh_from_db()
    assert trip_today.driver_reminder_sent_at is None
    assert trip_later.driver_reminder_sent_at is None
