import os

from django.conf import settings
from django.core import signing
from django.db import connection
from django.http import Http404
from django.views.static import serve
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView

from apps.core.media import resolve_signed_path
from apps.core.responses import success_response


class HealthCheckView(APIView):
    permission_classes = [AllowAny]
    # Render's infra polls this every few seconds; the default AnonRateThrottle
    # (100/hour) would otherwise throttle the health probe itself, causing
    # Render to see failing health checks and restart a perfectly healthy app.
    throttle_classes = []

    def get(self, request):
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        return success_response({"database": "ok"}, "Service healthy")


class SecureMediaView(APIView):
    """Serves a MEDIA_ROOT file only via a short-lived signed token (see
    apps.core.media) — there is no other way to reach uploaded documents;
    the raw /media/ prefix is not routed at all (see config/urls.py)."""

    permission_classes = [AllowAny]  # the signed token itself is the auth

    def get(self, request, token):
        try:
            relative_path = resolve_signed_path(token)
        except signing.BadSignature:
            raise Http404("Link has expired or is invalid.")

        media_root = os.path.abspath(settings.MEDIA_ROOT)
        full_path = os.path.abspath(os.path.join(media_root, relative_path))
        if os.path.commonpath([media_root, full_path]) != media_root:
            raise Http404("Invalid path.")  # path traversal guard

        return serve(request, relative_path, document_root=settings.MEDIA_ROOT)
