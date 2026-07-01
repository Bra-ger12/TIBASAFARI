from django.contrib import admin

from apps.operations.models import Vehicle


@admin.register(Vehicle)
class VehicleAdmin(admin.ModelAdmin):
    list_display = (
        "registration_number",
        "make",
        "model",
        "status",
        "has_wheelchair_access",
    )
    list_filter = ("status", "has_wheelchair_access")
    search_fields = ("registration_number", "make", "model")
