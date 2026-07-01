from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.trips.views import RecurringScheduleViewSet, TripViewSet

router = DefaultRouter()
router.register("recurring", RecurringScheduleViewSet, basename="recurring-schedule")
router.register("", TripViewSet, basename="trips")

urlpatterns = [path("", include(router.urls))]
