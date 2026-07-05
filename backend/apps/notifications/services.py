from django.utils import timezone


class NotificationService:
    def mark_read(self, notification):
        notification.is_read = True
        notification.read_at = timezone.now()
        notification.save(update_fields=["is_read", "read_at"])
        return notification
