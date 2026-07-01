from django.contrib import admin

from apps.billing.models import Invoice, Payment


class PaymentInline(admin.TabularInline):
    model = Payment
    extra = 0
    readonly_fields = ("processed_at", "created_at")


@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = ("invoice_number", "patient", "total_amount", "status", "created_at")
    list_filter = ("status",)
    search_fields = ("invoice_number", "patient__email")
    inlines = [PaymentInline]
    readonly_fields = ("invoice_number", "created_at", "updated_at")


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ("invoice", "amount", "method", "status", "processed_at")
    list_filter = ("method", "status")
    readonly_fields = ("created_at",)
