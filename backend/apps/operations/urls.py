from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.operations.views import VehicleExpenseViewSet, VehicleViewSet

router = DefaultRouter()
router.register("vehicles", VehicleViewSet, basename="vehicles")
router.register("vehicle-expenses", VehicleExpenseViewSet, basename="vehicle-expenses")

urlpatterns = [
    path("", include(router.urls)),
]
