"""
WebSocket consumer for driver location broadcasting (not trip-specific).

Dispatchers connect to ws/driver/location/ to watch all active drivers on
the map. Drivers also post their location here when not on an active trip.
Clients authenticate by sending {"type": "auth", "token": "<jwt>"} as
their first message rather than a ?token= query param, which would
otherwise end up in proxy/server access logs.
"""
import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth.models import AnonymousUser

from apps.core.ws_auth import authenticate_ws_token

FLEET_GROUP = "fleet_location"


class DriverLocationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.authenticated = False
        self.is_driver = False
        self.can_watch_fleet = False
        await self.accept()

    async def disconnect(self, close_code):
        if getattr(self, "can_watch_fleet", False):
            await self.channel_layer.group_discard(FLEET_GROUP, self.channel_name)

    async def receive(self, text_data):
        """After auth, drivers post: {"lat": 0.0, "lng": 0.0}"""
        if not self.authenticated:
            await self._authenticate(text_data)
            return

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
    def _check_can_watch_fleet(self, user):
        from apps.rbac.permissions import has_permission

        return has_permission(user, "manage_trips")

    @database_sync_to_async
    def _update_location(self, user, lat, lng):
        from django.utils import timezone

        from apps.drivers.models import DriverProfile

        DriverProfile.objects.filter(user=user).update(
            current_latitude=lat,
            current_longitude=lng,
            last_location_at=timezone.now(),
        )

    async def _authenticate(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            data = {}
        if data.get("type") != "auth":
            await self.close(code=4001)
            return

        user = await authenticate_ws_token(data.get("token"))
        if not user or isinstance(user, AnonymousUser):
            await self.close(code=4001)
            return

        self.scope["user"] = user
        self.is_driver = await self._check_driver(user)
        # Only dispatch/admin users receive the fleet-wide broadcast — any
        # authenticated user (including patients) was previously added to
        # FLEET_GROUP and could watch every driver's live GPS position.
        # Drivers can still post their own location even though they
        # aren't added to the receive group.
        self.can_watch_fleet = await self._check_can_watch_fleet(user)
        if self.can_watch_fleet:
            await self.channel_layer.group_add(FLEET_GROUP, self.channel_name)
        self.authenticated = True
        await self.send(text_data=json.dumps({"type": "auth_ok"}))
