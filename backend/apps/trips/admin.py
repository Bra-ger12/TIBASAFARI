from django.contrib import admin

from apps.trips.models import RecurringSchedule, Trip, TripRating


@admin.register(Trip)
class TripAdmin(admin.ModelAdmin):
    list_display = ("id", "patient", "driver", "status", "scheduled_at", "is_recurring")
    list_filter = ("status", "scheduled_at")
    search_fields = (
        "patient__email",
        "driver__email",
        "pickup_address",
        "destination_address",
    )
    list_select_related = ("patient", "driver", "recurring_schedule")

    @admin.display(boolean=True, description="Recurring")
    def is_recurring(self, obj):
        return obj.recurring_schedule_id is not None


@admin.register(RecurringSchedule)
class RecurringScheduleAdmin(admin.ModelAdmin):
    list_display = ("id", "patient", "frequency", "start_date", "end_date", "is_active", "last_generated_date")
    list_filter = ("frequency", "is_active")
    search_fields = ("patient__email", "pickup_address", "destination_address")
    list_select_related = ("patient",)


@admin.register(TripRating)
class TripRatingAdmin(admin.ModelAdmin):
    list_display = ("id", "trip", "driver", "patient", "score", "created_at")
    list_filter = ("score", "created_at")
    search_fields = ("trip__id", "patient__email", "trip__driver__email", "comment")
    list_select_related = ("trip", "trip__driver", "patient")

    @admin.display(description="Driver")
    def driver(self, obj):
        return obj.trip.driver

