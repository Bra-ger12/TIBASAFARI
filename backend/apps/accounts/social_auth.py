"""Verifies Google / Apple identity tokens against their published JWKS.

Deliberately dependency-light: PyJWT's PyJWKClient fetches signing keys via
stdlib urllib, so no google-auth or requests package is needed (neither is
installed in this project).
"""
import jwt
from django.conf import settings
from rest_framework import exceptions

_GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"
_GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"]

_APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
_APPLE_ISSUER = "https://appleid.apple.com"

# Lazily created — PyJWKClient caches fetched keys internally, so reuse one
# client per provider rather than re-fetching the JWKS on every request.
_jwk_clients: dict[str, "jwt.PyJWKClient"] = {}


def _jwk_client(url: str) -> "jwt.PyJWKClient":
    if url not in _jwk_clients:
        _jwk_clients[url] = jwt.PyJWKClient(url)
    return _jwk_clients[url]


def verify_google_id_token(id_token: str) -> dict:
    """Returns {"email", "full_name", "provider_id"} or raises a DRF
    exception. Requires GOOGLE_OAUTH_CLIENT_IDS to be configured."""
    if not settings.GOOGLE_OAUTH_CLIENT_IDS:
        raise exceptions.ValidationError(
            "Google sign-in is not configured on this server."
        )
    try:
        signing_key = _jwk_client(_GOOGLE_JWKS_URL).get_signing_key_from_jwt(id_token)
        claims = jwt.decode(
            id_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=settings.GOOGLE_OAUTH_CLIENT_IDS,
            issuer=_GOOGLE_ISSUERS,
        )
    except jwt.PyJWTError as exc:
        raise exceptions.AuthenticationFailed(f"Invalid Google token: {exc}") from exc

    if not claims.get("email_verified", True):
        raise exceptions.AuthenticationFailed("Google email is not verified")

    email = claims.get("email")
    if not email:
        raise exceptions.AuthenticationFailed("Google token did not include an email")

    return {
        "email": email,
        "full_name": claims.get("name") or email.split("@")[0],
        "provider_id": claims["sub"],
    }


def verify_apple_id_token(id_token: str) -> dict:
    """Returns {"email", "full_name", "provider_id"} or raises a DRF
    exception. Requires APPLE_SIGN_IN_CLIENT_IDS to be configured.

    Apple only ever includes the user's name in the ONE-TIME `user` JSON
    payload the client receives on first authorization — never in the
    id_token itself — so `full_name` here is always None; callers should
    fall back to a client-supplied name on first sign-in.
    """
    if not settings.APPLE_SIGN_IN_CLIENT_IDS:
        raise exceptions.ValidationError(
            "Apple sign-in is not configured on this server."
        )
    try:
        signing_key = _jwk_client(_APPLE_JWKS_URL).get_signing_key_from_jwt(id_token)
        claims = jwt.decode(
            id_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=settings.APPLE_SIGN_IN_CLIENT_IDS,
            issuer=_APPLE_ISSUER,
        )
    except jwt.PyJWTError as exc:
        raise exceptions.AuthenticationFailed(f"Invalid Apple token: {exc}") from exc

    email = claims.get("email")
    if not email:
        raise exceptions.AuthenticationFailed(
            "Apple did not provide an email for this account"
        )

    return {
        "email": email,
        "full_name": None,
        "provider_id": claims["sub"],
    }
