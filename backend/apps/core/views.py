from django.core import signing
from django.core.exceptions import SuspiciousOperation
from django.core.files.storage import default_storage
from django.db import connection
from django.http import FileResponse, Http404
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
    """Serves a stored file (local disk in dev, Cloudinary in production —
    see DEFAULT_FILE_STORAGE) only via a short-lived signed token (see
    apps.core.media) — there is no other way to reach uploaded documents;
    the raw /media/ prefix is not routed at all (see config/urls.py)."""

    permission_classes = [AllowAny]  # the signed token itself is the auth

    def get(self, request, token):
        try:
            relative_path = resolve_signed_path(token)
        except signing.BadSignature:
            raise Http404("Link has expired or is invalid.")

        try:
            file = default_storage.open(relative_path, "rb")
        except (FileNotFoundError, SuspiciousOperation) as exc:
            raise Http404("File not found.") from exc

        return FileResponse(file)
