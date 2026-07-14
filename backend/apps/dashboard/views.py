from datetime import timedelta

from django.db.models import Sum
from django.utils import timezone
from rest_framework.views import APIView

from apps.accounts.models import User
from apps.billing.models import Payment
from apps.core.responses import success_response
from apps.drivers.models import DriverProfile
from apps.patients.models import PatientProfile
from apps.rbac.permissions import RBACPermission
from apps.trips.models import Trip
from apps.trips.serializers import TripSerializer


def _revenue_stats():
    """Revenue actually collected (Payment.processed_at is set the moment a
    payment is confirmed COMPLETED — see InvoiceService.record_payment /
    verify_payment), compared day-over-day."""
    today = timezone.localdate()
    yesterday = today - timedelta(days=1)
    completed = Payment.objects.filter(status=Payment.Status.COMPLETED)
    revenue_today = completed.filter(processed_at__date=today).aggregate(
        total=Sum("amount")
    )["total"] or 0
    revenue_yesterday = completed.filter(processed_at__date=yesterday).aggregate(
        total=Sum("amount")
    )["total"] or 0
    if revenue_yesterday:
        trend_pct = round(
            float((revenue_today - revenue_yesterday) / revenue_yesterday * 100), 1
        )
    else:
        trend_pct = 100.0 if revenue_today else 0.0
    return {
        "today": revenue_today,
        "yesterday": revenue_yesterday,
        "trend_pct": trend_pct,
    }


class DashboardStatsView(APIView):
    permission_classes = [RBACPermission]
    permission_required = "view_dashboard"

    def get(self, request):
        data = {
            "users": {
                "total": User.objects.count(),
                "active": User.objects.filter(is_active=True).count(),
                "inactive": User.objects.filter(is_active=False).count(),
            },
            "drivers": {
                "total": DriverProfile.objects.count(),
                "available": DriverProfile.objects.filter(is_available=True).count(),
            },
            "patients": {
                "total": PatientProfile.objects.count(),
            },
            "trips": {
                "total": Trip.objects.count(),
                "requested": Trip.objects.filter(status=Trip.Status.REQUESTED).count(),
                "active": Trip.objects.filter(
                    status__in=[
                        Trip.Status.ASSIGNED,
                        Trip.Status.ACCEPTED,
                        Trip.Status.EN_ROUTE,
                        Trip.Status.ARRIVED,
                    ]
                ).count(),
                "completed": Trip.objects.filter(status=Trip.Status.COMPLETED).count(),
                "cancelled": Trip.objects.filter(status=Trip.Status.CANCELLED).count(),
            },
            "revenue": _revenue_stats(),
        }
        return success_response(data)


class ActiveTripsView(APIView):
    permission_classes = [RBACPermission]
    permission_required = "view_dashboard"

    def get(self, request):
        trips = Trip.objects.filter(
            status__in=[
                Trip.Status.ASSIGNED,
                Trip.Status.ACCEPTED,
                Trip.Status.EN_ROUTE,
                Trip.Status.ARRIVED,
            ]
        ).select_related("patient", "driver")
        return success_response(TripSerializer(trips, many=True).data)


class CompletedTripsView(APIView):
    permission_classes = [RBACPermission]
    permission_required = "view_dashboard"

    def get(self, request):
        trips = Trip.objects.filter(status=Trip.Status.COMPLETED).select_related(
            "patient",
            "driver",
        )
        return success_response(TripSerializer(trips, many=True).data)

