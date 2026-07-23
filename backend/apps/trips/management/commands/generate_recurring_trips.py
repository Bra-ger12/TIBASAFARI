from datetime import timedelta

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from apps.trips.models import RecurringSchedule
from apps.trips.recurrence import next_occurrence_after
from apps.trips.services import TripService


class Command(BaseCommand):
    help = (
        "Book Trips for RecurringSchedule occurrences that are due within the "
        "lookahead window and haven't been generated yet. Intended to run daily "
        "(see render.yaml's tibasafari-recurring-trips cron job) — the first "
        "occurrence of a schedule is already booked synchronously on creation "
        "(see RecurringScheduleViewSet.perform_create); this command is what "
        "books every occurrence after that."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--lookahead-days",
            type=int,
            default=1,
            help="Book occurrences due up to this many days from today (default 1, "
            "i.e. today and tomorrow) so dispatch has lead time to assign a driver.",
        )

    def handle(self, *args, **options):
        service = TripService()
        horizon = timezone.localdate() + timedelta(days=options["lookahead_days"])
        booked = sum(
            self._catch_up_schedule(schedule, service, horizon)
            for schedule in RecurringSchedule.objects.filter(is_active=True).select_related("patient")
        )
        self.stdout.write(self.style.SUCCESS(f"Booked {booked} recurring trip(s)."))

    def _catch_up_schedule(self, schedule, service, horizon) -> int:
        booked = 0
        with transaction.atomic():
            schedule = RecurringSchedule.objects.select_for_update().get(pk=schedule.pk)
            cursor = schedule.last_generated_date or schedule.start_date
            while True:
                occurrence = next_occurrence_after(schedule, cursor)
                if occurrence is None or occurrence > horizon:
                    break
                service.book_recurring_occurrence(schedule, occurrence)
                schedule.last_generated_date = occurrence
                schedule.save(update_fields=["last_generated_date"])
                cursor = occurrence
                booked += 1
        return booked
