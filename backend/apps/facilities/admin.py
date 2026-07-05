from django.contrib import admin

from apps.facilities.models import HealthFacility


@admin.register(HealthFacility)
class HealthFacilityAdmin(admin.ModelAdmin):
    list_display = ("name", "facility_type", "region", "district", "is_active")
    list_filter = ("facility_type", "region", "is_active")
    search_fields = ("name", "region", "district")
    list_editable = ("is_active",)
