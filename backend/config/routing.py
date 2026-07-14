from django.urls import re_path

from apps.trips.consumers import DispatchConsumer, TripConsumer
from apps.drivers.consumers import DriverLocationConsumer
from apps.notifications.consumers import NotificationConsumer

websocket_urlpatterns = [
    # Driver streams live GPS to a trip room; patients/dispatchers subscribe
    re_path(r"^ws/trips/(?P<trip_id>[0-9a-f-]+)/$", TripConsumer.as_asgi()),
    # Driver posts own location updates
    re_path(r"^ws/driver/location/$", DriverLocationConsumer.as_asgi()),
    # Personal notification channel per user
    re_path(r"^ws/notifications/$", NotificationConsumer.as_asgi()),
    # Dispatch-wide feed for admin_web's live map (all active trips/drivers)
    re_path(r"^ws/dispatch/$", DispatchConsumer.as_asgi()),
]
