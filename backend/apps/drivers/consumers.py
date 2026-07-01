"""
WebSocket consumer for driver location broadcasting (not trip-specific).

Dispatchers connect to ws/driver/location/ to watch all active drivers on the map.
Drivers also post their location here when not on an active trip.
"""
import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth.models import AnonymousUser

FLEET_GROUP = "fleet_location"


class DriverLocationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        user = self.scope.get("user")
        if not user or isinstance(user, AnonymousUser):
            await self.close(code=4001)
            return

        self.is_driver = await self._check_driver(user)
        await self.channel_layer.group_add(FLEET_GROUP, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(FLEET_GROUP, self.channel_name)

    async def receive(self, text_data):
        """Drivers post: {"lat": 0.0, "lng": 0.0}"""
        if not self.is_driver:
            return
        user = self.scope["user"]
        try:
            data = json.loads(text_data)
            lat = float(data["lat"])
            lng = float(data["lng"])
        except (json.JSONDecodeError, KeyError, ValueError):
            return

        await self._update_location(user, lat, lng)
        await self.channel_layer.group_send(
            FLEET_GROUP,
            {
                "type": "fleet.position",
                "driver_id": str(user.id),
                "lat": lat,
                "lng": lng,
            },
        )

    async def fleet_position(self, event):
        await self.send(
            text_data=json.dumps(
                {
                    "type": "fleet_position",
                    "driver_id": event["driver_id"],
                    "lat": event["lat"],
                    "lng": event["lng"],
                }
            )
        )

    @database_sync_to_async
    def _check_driver(self, user):
        from apps.drivers.models import DriverProfile

        return DriverProfile.objects.filter(user=user).exists()

    @database_sync_to_async
    def _update_location(self, user, lat, lng):
        from django.utils import timezone

        from apps.drivers.models import DriverProfile

        DriverProfile.objects.filter(user=user).update(
            current_latitude=lat,
            current_longitude=lng,
            last_location_at=timezone.now(),
        )
