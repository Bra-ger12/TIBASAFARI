from config.settings import *  # noqa: F403

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "test.sqlite3",  # noqa: F405
    }
}

SECRET_KEY = "test-secret-key-for-tiba-safari-backend-checks"
PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
]

EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
STATIC_ROOT = BASE_DIR / "test_staticfiles"  # noqa: F405
MIDDLEWARE = [
    middleware
    for middleware in globals()["MIDDLEWARE"]
    if middleware != "whitenoise.middleware.WhiteNoiseMiddleware"
]

SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
