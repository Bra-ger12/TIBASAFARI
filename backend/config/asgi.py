import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

# Initialize Django ASGI application early to populate app registry before
# importing consumers and routing modules.
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator

from config.routing import websocket_urlpatterns

# No query-string JWT middleware here on purpose: each consumer now
# authenticates from the client's first WS message instead of a ?token=
# query param (see apps.core.ws_auth.authenticate_ws_token), so a JWT never
# appears in the connection URL / access logs.
application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": AllowedHostsOriginValidator(URLRouter(websocket_urlpatterns)),
    }
)
