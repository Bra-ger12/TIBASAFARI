"""Signed, time-limited media URLs.

The files behind MEDIA_ROOT (patient medical documents, driver license
scans, trip signatures/photos) contain PII and must not be servable to
anyone who guesses/finds the URL. But they're consumed via plain
`<img src>` / `window.open()` in three different clients (Flutter mobile,
Flutter web, admin_web's browser tabs) with no way to attach an
Authorization header — so instead of gating on a bearer token, each URL
is signed and expires shortly after being handed out by an already
-authorized API response (the same trust model as S3/GCS presigned URLs).
"""
from django.core import signing

_SALT = "secure-media"
_URL_TTL_SECONDS = 15 * 60  # 15 minutes — long enough for a normal viewing session


def build_secure_media_url(request, file_field) -> str | None:
    """Given a FileField/ImageField value, returns an absolute signed URL,
    or None if no file is set."""
    if not file_field:
        return None
    token = signing.dumps({"path": file_field.name}, salt=_SALT)
    path = f"/secure-media/{token}/"
    if request is not None:
        return request.build_absolute_uri(path)
    return path


def resolve_signed_path(token: str) -> str:
    """Verifies the token and returns the underlying relative media path.
    Raises signing.BadSignature (expired or tampered) if invalid."""
    data = signing.loads(token, salt=_SALT, max_age=_URL_TTL_SECONDS)
    return data["path"]
