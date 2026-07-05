from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.notifications.views import BroadcastViewSet, NotificationViewSet

router = DefaultRouter()
router.register("broadcasts", BroadcastViewSet, basename="broadcasts")
router.register("", NotificationViewSet, basename="notifications")

urlpatterns = [path("", include(router.urls))]

