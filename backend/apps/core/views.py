from django.db import connection
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView

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
