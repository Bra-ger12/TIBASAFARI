"""
WebSocket consumer for real-time trip tracking.

Clients connect to ws/trips/<trip_id>/?token=<jwt>
The driver posts location updates; all room members receive them.
"""
import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth.models import AnonymousUser


class TripConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.trip_id = self.scope["url_route"]["kwargs"]["trip_id"]
        self.room_group = f"trip_{self.trip_id}"
        user = self.scope.get("user")

        if not user or isinstance(user, AnonymousUser):
            await self.close(code=4001)
            return

        allowed = await self._can_access_trip(user, self.trip_id)
        if not allowed:
            await self.close(code=4003)
            return

        await self.channel_layer.group_add(self.room_group, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "room_group"):
            await self.channel_layer.group_discard(self.room_group, self.channel_name)

    async def receive(self, text_data):
        """Driver sends: {"type": "location", "lat": 0.0, "lng": 0.0}"""
        user = self.scope.get("user")
        if not user or isinstance(user, AnonymousUser):
            return

        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        msg_type = data.get("type")

        if msg_type == "location":
            lat = data.get("lat")
            lng = data.get("lng")
            if lat is not None and lng is not None:
                await self._save_driver_location(user, lat, lng)
                await self.channel_layer.group_send(
                    self.room_group,
                    {
                        "type": "driver.location",
                        "driver_id": str(user.id),
                        "lat": lat,
                        "lng": lng,
                    },
                )

        elif msg_type == "chat":
            body = (data.get("body") or "").strip()
            if body:
                await self._send_chat_message(user, body)

    # ── Group message handlers ──────────────────────────────────────────────

    async def driver_location(self, event):
        await self.send(
            text_data=json.dumps(
                {
                    "type": "location",
                    "driver_id": event["driver_id"],
                    "lat": event["lat"],
                    "lng": event["lng"],
                }
            )
        )

    async def trip_status(self, event):
        await self.send(
            text_data=json.dumps(
                {
                    "type": "status",
                    "trip_id": event["trip_id"],
                    "status": event["status"],
                }
            )
        )

    async def trip_chat(self, event):
        await self.send(
            text_data=json.dumps(
                {
                    "type": "chat",
                    "id": event["id"],
                    "trip_id": event["trip_id"],
                    "sender_id": event["sender_id"],
                    "sender_name": event["sender_name"],
                    "body": event["body"],
                    "created_at": event["created_at"],
                }
            )
        )

    # ── DB helpers ──────────────────────────────────────────────────────────

    @database_sync_to_async
    def _can_access_trip(self, user, trip_id):
        from apps.rbac.permissions import has_permission
        from apps.trips.models import Trip

        try:
            trip = Trip.objects.get(id=trip_id)
        except Trip.DoesNotExist:
            return False
        if has_permission(user, "manage_trips"):
            return True
        return trip.patient_id == user.id or trip.driver_id == user.id

    @database_sync_to_async
    def _save_driver_location(self, user, lat, lng):
        from django.utils import timezone

        from apps.drivers.models import DriverProfile

        DriverProfile.objects.filter(user=user).update(
            current_latitude=lat,
            current_longitude=lng,
            last_location_at=timezone.now(),
        )

    @database_sync_to_async
    def _send_chat_message(self, user, body):
        from apps.trips.models import Trip
        from apps.trips.services import TripService

        trip = Trip.objects.get(id=self.trip_id)
        TripService().send_trip_message(trip, sender=user, body=body)
