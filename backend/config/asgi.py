import os

from django.core.asgi import get_asgi_application
from django.conf import settings

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

# Initialize Django ASGI application early to populate app registry before
# importing consumers and routing modules.
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import OriginValidator

from config.routing import websocket_urlpatterns


def _websocket_allowed_origins():
    if settings.CORS_ALLOW_ALL_ORIGINS:
        return ["*"]

    origins = [
        *settings.CORS_ALLOWED_ORIGINS,
        *settings.CSRF_TRUSTED_ORIGINS,
    ]
    return sorted(set(origin for origin in origins if origin))


# No query-string JWT middleware here on purpose: each consumer now
# authenticates from the client's first WS message instead of a ?token=
# query param (see apps.core.ws_auth.authenticate_ws_token), so a JWT never
# appears in the connection URL / access logs.
application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": OriginValidator(
            URLRouter(websocket_urlpatterns),
            _websocket_allowed_origins(),
        ),
    }
)
