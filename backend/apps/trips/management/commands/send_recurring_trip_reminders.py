from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.trips.models import Trip
from apps.trips.services import TripService


class Command(BaseCommand):
    help = (
        "Notify drivers about recurring-schedule trips they're assigned to that "
        "are scheduled for tomorrow, so they get a day's notice (see render.yaml's "
        "tibasafari-recurring-trip-reminders cron job). Trip.driver_reminder_sent_at "
        "guards against double-sending on reruns."
    )

    def handle(self, *args, **options):
        service = TripService()
        tomorrow = timezone.localdate() + timedelta(days=1)
        due = Trip.objects.filter(
            recurring_schedule__isnull=False,
            driver__isnull=False,
            driver_reminder_sent_at__isnull=True,
            scheduled_at__date=tomorrow,
        ).exclude(status__in=[Trip.Status.COMPLETED, Trip.Status.CANCELLED])

        count = 0
        for trip in due:
            service.send_driver_reminder(trip)
            count += 1

        self.stdout.write(self.style.SUCCESS(f"Reminded driver(s) for {count} recurring trip(s)."))
