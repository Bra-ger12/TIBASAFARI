from django.test import override_settings

from config.asgi import _websocket_allowed_origins


@override_settings(
    CORS_ALLOW_ALL_ORIGINS=False,
    CORS_ALLOWED_ORIGINS=["https://tibasafari-admin.onrender.com"],
    CSRF_TRUSTED_ORIGINS=["https://tibasafari-backend.onrender.com"],
)
def test_websocket_origins_include_configured_browser_origins():
    assert _websocket_allowed_origins() == [
        "https://tibasafari-admin.onrender.com",
        "https://tibasafari-backend.onrender.com",
    ]


@override_settings(CORS_ALLOW_ALL_ORIGINS=True)
def test_websocket_origins_allow_all_for_local_debug_cors_mode():
    assert _websocket_allowed_origins() == ["*"]
