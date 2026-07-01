from django.contrib import admin

from apps.drivers.models import DriverProfile


@admin.register(DriverProfile)
class DriverProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "license_number", "vehicle", "is_available")
    list_filter = ("is_available",)
    search_fields = ("user__email", "user__full_name", "license_number")
    list_select_related = ("user", "vehicle")

