from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.drivers.views import DriverProfileViewSet, DriverSignupView, GoogleAuthView

router = DefaultRouter()
router.register("profiles", DriverProfileViewSet, basename="driver-profiles")

urlpatterns = [
    path("signup/", DriverSignupView.as_view(), name="driver-signup"),
    path("auth/google/", GoogleAuthView.as_view(), name="driver-google-auth"),
    path("", include(router.urls)),
]
