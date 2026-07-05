from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.utils import timezone

from apps.notifications.models import Notification


class NotificationService:
    def mark_read(self, notification):
        notification.is_read = True
        notification.read_at = timezone.now()
        notification.save(update_fields=["is_read", "read_at"])
        return notification


_AUDIENCE_ROLE_CODES = {
    "drivers": "DRIVER",
    "patients": "PATIENT",
    "admins": "ADMIN",
}


def send_broadcast(*, title: str, message: str, audience: str) -> int:
    """Creates a Notification for every user matching `audience` and pushes
    each one over their personal ws/notifications/ channel. Returns the
    number of recipients."""
    from apps.accounts.models import User

    recipients_qs = User.objects.filter(is_active=True)
    role_code = _AUDIENCE_ROLE_CODES.get(audience)
    if role_code:
        recipients_qs = recipients_qs.filter(
            role_assignments__role__code__iexact=role_code
        ).distinct()

    recipients = list(recipients_qs)
    notifications = [
        Notification(recipient=user, title=title, message=message)
        for user in recipients
    ]
    Notification.objects.bulk_create(notifications)

    now_iso = timezone.now().isoformat()
    channel_layer = get_channel_layer()
    for notification in notifications:
        try:
            async_to_sync(channel_layer.group_send)(
                f"notifications_{notification.recipient_id}",
                {
                    "type": "notification.push",
                    "id": str(notification.id),
                    "title": title,
                    "message": message,
                    "metadata": {},
                    "created_at": now_iso,
                },
            )
        except Exception:
            pass

    return len(notifications)
