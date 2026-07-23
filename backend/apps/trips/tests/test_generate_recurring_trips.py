from datetime import date, time, timedelta
from io import StringIO

import pytest
from django.core.management import call_command
from django.utils import timezone

from apps.accounts.models import User
from apps.trips.models import RecurringSchedule, Trip


def _make_patient(email="patient-cron@example.com"):
    return User.objects.create_user(
        email=email,
        password="StrongPass123",
        full_name="Cron Patient",
        status=User.Status.ACTIVE,
        is_active=True,
    )


def _run_command(**kwargs):
    out = StringIO()
    call_command("generate_recurring_trips", stdout=out, **kwargs)
    return out.getvalue()


@pytest.mark.django_db
def test_books_occurrences_due_within_lookahead_window():
    patient = _make_patient()
    today = timezone.localdate()
    schedule = RecurringSchedule.objects.create(
        patient=patient,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_time=time(7, 0),
        frequency=RecurringSchedule.Frequency.DAILY,
        start_date=today - timedelta(days=1),
        last_generated_date=today - timedelta(days=1),
    )

    # lookahead_days=1 books everything through tomorrow: today and tomorrow.
    _run_command(lookahead_days=1)

    booked_dates = set(
        Trip.objects.filter(recurring_schedule=schedule).values_list("scheduled_at__date", flat=True)
    )
    assert booked_dates == {today, today + timedelta(days=1)}
    schedule.refresh_from_db()
    assert schedule.last_generated_date == today + timedelta(days=1)


@pytest.mark.django_db
def test_catches_up_multiple_missed_occurrences_in_one_run():
    patient = _make_patient()
    today = timezone.localdate()
    schedule = RecurringSchedule.objects.create(
        patient=patient,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_time=time(7, 0),
        frequency=RecurringSchedule.Frequency.DAILY,
        start_date=today - timedelta(days=5),
        last_generated_date=today - timedelta(days=5),
    )

    _run_command(lookahead_days=0)

    booked_dates = set(
        Trip.objects.filter(recurring_schedule=schedule).values_list("scheduled_at__date", flat=True)
    )
    expected = {today - timedelta(days=n) for n in range(4, -1, -1)}
    assert booked_dates == expected
    schedule.refresh_from_db()
    assert schedule.last_generated_date == today


@pytest.mark.django_db
def test_does_not_rebook_already_generated_occurrence():
    patient = _make_patient()
    today = timezone.localdate()
    schedule = RecurringSchedule.objects.create(
        patient=patient,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_time=time(7, 0),
        frequency=RecurringSchedule.Frequency.DAILY,
        start_date=today,
        last_generated_date=today,
    )

    _run_command(lookahead_days=1)

    assert Trip.objects.filter(recurring_schedule=schedule).count() == 1


@pytest.mark.django_db
def test_inactive_schedule_is_skipped():
    patient = _make_patient()
    today = timezone.localdate()
    schedule = RecurringSchedule.objects.create(
        patient=patient,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_time=time(7, 0),
        frequency=RecurringSchedule.Frequency.DAILY,
        start_date=today - timedelta(days=1),
        last_generated_date=today - timedelta(days=1),
        is_active=False,
    )

    _run_command(lookahead_days=1)

    assert Trip.objects.filter(recurring_schedule=schedule).count() == 0


@pytest.mark.django_db
def test_respects_end_date():
    patient = _make_patient()
    today = timezone.localdate()
    schedule = RecurringSchedule.objects.create(
        patient=patient,
        pickup_address="123 Pickup St",
        destination_address="456 Destination Ave",
        pickup_time=time(7, 0),
        frequency=RecurringSchedule.Frequency.DAILY,
        start_date=today - timedelta(days=2),
        last_generated_date=today - timedelta(days=2),
        end_date=today - timedelta(days=1),
    )

    _run_command(lookahead_days=1)

    trip = Trip.objects.get(recurring_schedule=schedule)
    assert trip.scheduled_at.date() == today - timedelta(days=1)
