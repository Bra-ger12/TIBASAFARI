from django.contrib import admin

from apps.trips.models import Trip


@admin.register(Trip)
class TripAdmin(admin.ModelAdmin):
    list_display = ("id", "patient", "driver", "status", "scheduled_at")
    list_filter = ("status", "scheduled_at")
    search_fields = (
        "patient__email",
        "driver__email",
        "pickup_address",
        "destination_address",
    )
    list_select_related = ("patient", "driver")

