from django.utils import timezone
from rest_framework import filters, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated

from apps.core.responses import success_response
from apps.notifications.models import Broadcast, Notification, NotificationPreference
from apps.notifications.serializers import (
    BroadcastSerializer,
    NotificationPreferenceSerializer,
    NotificationSerializer,
)
from apps.notifications.services import NotificationService, send_broadcast
from apps.rbac.permissions import RBACPermission


class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    # get_queryset already scopes to the requesting user (unless
    # staff/superuser), so IsAuthenticated was already the effective
    # behavior via DRF's global default — declared explicitly here to match
    # every other view in this codebase.
    permission_classes = [IsAuthenticated]
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


class BroadcastViewSet(viewsets.ModelViewSet):
    """Admin-only: send a message to a group of users (all / drivers /
    patients / admins) and list past broadcasts."""

    serializer_class = BroadcastSerializer
    queryset = Broadcast.objects.all()
    http_method_names = ["get", "post", "head", "options"]
    permission_classes = [RBACPermission]
    ordering_fields = ["created_at"]
    permission_map = {
        "list": "manage_users",
        "retrieve": "manage_users",
        "create": "manage_users",
    }

    def perform_create(self, serializer):
        recipient_count = send_broadcast(
            title=serializer.validated_data["title"],
            message=serializer.validated_data["message"],
            audience=serializer.validated_data["audience"],
        )
        serializer.save(sent_by=self.request.user, recipient_count=recipient_count)
