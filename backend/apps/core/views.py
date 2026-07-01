from django.db import connection
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView

from apps.core.responses import success_response


class HealthCheckView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        return success_response({"database": "ok"}, "Service healthy")
