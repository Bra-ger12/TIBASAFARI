from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.operations.views import VehicleViewSet

router = DefaultRouter()
router.register("vehicles", VehicleViewSet, basename="vehicles")

urlpatterns = [
    path("", include(router.urls)),
]
