"""
WebSocket consumer for real-time push notifications.

Each user connects to ws/notifications/ and authenticates by sending
{"type": "auth", "token": "<jwt>"} as their first message (rather than a
?token= query param, which would otherwise end up in proxy/server access
logs), then joins their own personal group. The backend sends to that
group whenever a notification is saved.
"""
import json

from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth.models import AnonymousUser

from apps.core.ws_auth import authenticate_ws_token


class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.authenticated = False
        await self.accept()

    async def disconnect(self, close_code):
        if getattr(self, "authenticated", False) and hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        if not self.authenticated:
            await self._authenticate(text_data)
            return

        # Clients can send {"action": "mark_read", "notification_id": "..."}
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return
        if data.get("action") == "mark_read":
            await self._mark_read(data.get("notification_id"))

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
        self.group_name = f"notifications_{user.id}"
        self.authenticated = True
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.send(text_data=json.dumps({"type": "auth_ok"}))

    async def notification_push(self, event):
        """Receives a group message and forwards it to the WS client."""
        await self.send(
            text_data=json.dumps(
                {
                    "type": "notification",
                    "id": event["id"],
                    "title": event["title"],
                    "message": event["message"],
                    "metadata": event.get("metadata", {}),
                    "created_at": event["created_at"],
                }
            )
        )

    async def _mark_read(self, notification_id):
        if not notification_id:
            return
        from channels.db import database_sync_to_async
        from django.utils import timezone

        from apps.notifications.models import Notification

        @database_sync_to_async
        def _do_mark():
            Notification.objects.filter(
                id=notification_id,
                recipient=self.scope["user"],
                is_read=False,
            ).update(is_read=True, read_at=timezone.now())

        await _do_mark()
