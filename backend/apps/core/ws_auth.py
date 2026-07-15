"""JWT authentication helper for Django Channels WebSocket consumers.

Clients authenticate by sending {"type": "auth", "token": "<jwt>"} as their
first WS message after the connection is accepted, rather than passing the
token in the connection URL's ?token= query param. A URL (including its
query string) is commonly captured in server/proxy access logs, which
would otherwise leak live access tokens into log storage.
"""
from channels.db import database_sync_to_async
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import AccessToken


@database_sync_to_async
def authenticate_ws_token(token_str):
    if not token_str:
        return None
    from django.contrib.auth import get_user_model

    User = get_user_model()
    try:
        token = AccessToken(token_str)
        return User.objects.get(id=token["user_id"])
    except (InvalidToken, TokenError, User.DoesNotExist, KeyError):
        return None
