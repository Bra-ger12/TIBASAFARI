from django.contrib import admin

from apps.patients.models import PatientProfile


@admin.register(PatientProfile)
class PatientProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "mobility_needs", "created_at")
    search_fields = ("user__email", "user__full_name", "user__phone")
    list_select_related = ("user",)

