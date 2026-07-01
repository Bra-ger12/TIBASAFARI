from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.patients.views import PatientProfileViewSet, PatientSignupView, PatientTripRequestViewSet

router = DefaultRouter()
router.register("profiles", PatientProfileViewSet, basename="patient-profiles")
router.register("trip-requests", PatientTripRequestViewSet, basename="patient-trip-requests")

urlpatterns = [
    path("signup/", PatientSignupView.as_view(), name="patient-signup"),
    path("", include(router.urls)),
]
