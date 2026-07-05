from django.utils import timezone
from rest_framework import filters, viewsets
from rest_framework.decorators import action

from apps.core.responses import success_response
from apps.notifications.models import Notification, NotificationPreference
from apps.notifications.serializers import (
    NotificationPreferenceSerializer,
    NotificationSerializer,
)
from apps.notifications.services import NotificationService


class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    service = NotificationService()
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ["title", "message"]
    ordering_fields = ["created_at", "read_at"]

    def get_queryset(self):
        queryset = Notification.objects.select_related("recipient")
        if self.request.user.is_staff or self.request.user.is_superuser:
            return queryset
        return queryset.filter(recipient=self.request.user)

    @action(detail=True, methods=["post"], url_path="mark-read")
    def mark_read(self, request, pk=None):
        notification = self.service.mark_read(self.get_object())
        return success_response(self.get_serializer(notification).data)

    @action(detail=False, methods=["post"], url_path="mark-all-read")
    def mark_all_read(self, request):
        self.get_queryset().filter(is_read=False).update(
            is_read=True, read_at=timezone.now()
        )
        return success_response(None, "All notifications marked as read")

    @action(detail=False, methods=["get"], url_path="unread-count")
    def unread_count(self, request):
        count = self.get_queryset().filter(is_read=False).count()
        return success_response({"count": count})

    @action(detail=False, methods=["get", "patch"])
    def preferences(self, request):
        pref, _ = NotificationPreference.objects.get_or_create(user=request.user)
        if request.method == "PATCH":
            serializer = NotificationPreferenceSerializer(
                pref, data=request.data, partial=True
            )
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return success_response(serializer.data, "Preferences updated")
        return success_response(NotificationPreferenceSerializer(pref).data)
