from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.accounts.views import AdminSignupView, UserViewSet

router = DefaultRouter()
router.register("users", UserViewSet, basename="users")

urlpatterns = [
    path("signup/", AdminSignupView.as_view(), name="admin-signup"),
    path("", include(router.urls)),
]
