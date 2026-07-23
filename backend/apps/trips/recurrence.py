"""Pure date-math for turning a RecurringSchedule's pattern into occurrence
dates. Kept separate from services.py/the management command so the pattern
logic can be unit-tested without touching the DB or Trip creation."""
import calendar
from datetime import date, timedelta

from apps.trips.models import RecurringSchedule


def next_occurrence_after(schedule: RecurringSchedule, after: date) -> date | None:
    """Return the next date strictly after `after` that this schedule fires
    on, or None if the pattern has no more occurrences (past end_date)."""
    frequency = schedule.frequency
    candidate = after + timedelta(days=1)

    if frequency == RecurringSchedule.Frequency.DAILY:
        occurrence = candidate

    elif frequency == RecurringSchedule.Frequency.MONTHLY:
        occurrence = _next_monthly(schedule.start_date.day, candidate)

    elif frequency in (RecurringSchedule.Frequency.WEEKLY, RecurringSchedule.Frequency.BIWEEKLY):
        occurrence = _next_weekly(schedule, candidate)

    else:
        raise ValueError(f"Unknown frequency: {frequency}")

    if occurrence is None:
        return None
    if schedule.end_date and occurrence > schedule.end_date:
        return None
    return occurrence


def _next_monthly(day_of_month: int, candidate: date) -> date:
    year, month = candidate.year, candidate.month
    while True:
        last_day = calendar.monthrange(year, month)[1]
        occurrence = date(year, month, min(day_of_month, last_day))
        if occurrence >= candidate:
            return occurrence
        month += 1
        if month > 12:
            month = 1
            year += 1


def _next_weekly(schedule: RecurringSchedule, candidate: date) -> date | None:
    days = schedule.days_of_week or [schedule.start_date.weekday()]
    is_biweekly = schedule.frequency == RecurringSchedule.Frequency.BIWEEKLY

    # Cap the search — a schedule with an empty/invalid days_of_week and no
    # end_date could otherwise loop indefinitely.
    for offset in range(400):
        d = candidate + timedelta(days=offset)
        if d.weekday() not in days:
            continue
        if is_biweekly and not _on_biweekly_cycle(schedule.start_date, d):
            continue
        return d
    return None


def _on_biweekly_cycle(start_date: date, d: date) -> bool:
    """Weeks are counted from start_date's week; occurrences only fire on
    every *other* week from there (a simple day-count // 7 parity check,
    not calendar-week-boundary alignment)."""
    return ((d - start_date).days // 7) % 2 == 0
