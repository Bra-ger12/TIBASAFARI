from datetime import date

from apps.trips.models import RecurringSchedule
from apps.trips.recurrence import next_occurrence_after


def _schedule(**overrides):
    defaults = dict(
        frequency=RecurringSchedule.Frequency.WEEKLY,
        days_of_week=[0, 2, 4],  # Mon, Wed, Fri
        start_date=date(2026, 8, 3),  # a Monday
        end_date=None,
        pickup_time="07:00:00",
    )
    defaults.update(overrides)
    return RecurringSchedule(**defaults)


def test_daily_returns_next_calendar_day():
    schedule = _schedule(frequency=RecurringSchedule.Frequency.DAILY, days_of_week=[])
    assert next_occurrence_after(schedule, date(2026, 8, 3)) == date(2026, 8, 4)


def test_weekly_skips_to_next_matching_weekday():
    schedule = _schedule()
    # Booked Monday 8/3 already; next occurrence is Wednesday 8/5.
    assert next_occurrence_after(schedule, date(2026, 8, 3)) == date(2026, 8, 5)
    assert next_occurrence_after(schedule, date(2026, 8, 5)) == date(2026, 8, 7)  # Friday
    assert next_occurrence_after(schedule, date(2026, 8, 7)) == date(2026, 8, 10)  # next Monday


def test_weekly_defaults_to_start_date_weekday_when_days_of_week_empty():
    schedule = _schedule(days_of_week=[])
    assert next_occurrence_after(schedule, date(2026, 8, 3)) == date(2026, 8, 10)


def test_biweekly_only_fires_every_other_matching_week():
    schedule = _schedule(frequency=RecurringSchedule.Frequency.BIWEEKLY)
    # Week of 8/3 is the "on" week (offset 0). Next on-week matching day
    # after 8/3 within that same week is 8/5, then 8/7.
    assert next_occurrence_after(schedule, date(2026, 8, 3)) == date(2026, 8, 5)
    assert next_occurrence_after(schedule, date(2026, 8, 7)) == date(2026, 8, 17)  # skips 8/10 week


def test_monthly_uses_start_date_day_of_month():
    schedule = _schedule(frequency=RecurringSchedule.Frequency.MONTHLY, days_of_week=[], start_date=date(2026, 1, 31))
    # Clamped to the last day of shorter months.
    assert next_occurrence_after(schedule, date(2026, 1, 31)) == date(2026, 2, 28)
    assert next_occurrence_after(schedule, date(2026, 2, 28)) == date(2026, 3, 31)


def test_returns_none_past_end_date():
    schedule = _schedule(end_date=date(2026, 8, 6))
    assert next_occurrence_after(schedule, date(2026, 8, 3)) == date(2026, 8, 5)
    assert next_occurrence_after(schedule, date(2026, 8, 5)) is None
