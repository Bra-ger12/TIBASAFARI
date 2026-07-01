from rest_framework.views import APIView

from apps.accounts.models import User
from apps.core.responses import success_response
from apps.drivers.models import DriverProfile
from apps.patients.models import PatientProfile
from apps.rbac.permissions import RBACPermission
from apps.trips.models import Trip
from apps.trips.serializers import TripSerializer


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

