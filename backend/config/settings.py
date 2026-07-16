from datetime import timedelta
from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent

env = environ.Env(
    DEBUG=(bool, False),
    ACCESS_TOKEN_LIFETIME_MINUTES=(int, 60),
    REFRESH_TOKEN_LIFETIME_DAYS=(int, 14),
    FARE_BASE_RATE=(float, 2.50),
    FARE_PER_KM=(float, 1.20),
    FARE_PER_MINUTE=(float, 0.25),
    FARE_MINIMUM=(float, 8.00),
    FARE_WHEELCHAIR_SURCHARGE=(float, 5.00),
)
environ.Env.read_env(BASE_DIR / ".env")

DEBUG = env("DEBUG")
DJANGO_ENV = env("DJANGO_ENV", default="development")

# The insecure fallback only applies when DEBUG=True (local dev without a
# .env file) — a DEBUG=False deployment missing SECRET_KEY fails loudly at
# boot (django-environ raises ImproperlyConfigured) instead of silently
# running with a key that's sitting in source control. render.yaml already
# sets SECRET_KEY via generateValue: true, so this never applies to the
# real deployment.
SECRET_KEY = (
    env("SECRET_KEY", default="unsafe-development-secret-key")
    if DEBUG
    else env("SECRET_KEY")
)

ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=["localhost", "127.0.0.1"])
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])
CORS_ALLOWED_ORIGINS = env.list("CORS_ALLOWED_ORIGINS", default=[])

# Render sets this to the service's own hostname (e.g. tibasafari-backend.onrender.com)
# at runtime — add it automatically so ALLOWED_HOSTS/CSRF don't need updating per-deploy.
RENDER_EXTERNAL_HOSTNAME = env("RENDER_EXTERNAL_HOSTNAME", default="")
if RENDER_EXTERNAL_HOSTNAME:
    ALLOWED_HOSTS.append(RENDER_EXTERNAL_HOSTNAME)
    CSRF_TRUSTED_ORIGINS.append(f"https://{RENDER_EXTERNAL_HOSTNAME}")
CORS_ALLOW_ALL_ORIGINS = env.bool(
    "CORS_ALLOW_ALL_ORIGINS",
    default=DEBUG and not CORS_ALLOWED_ORIGINS,
)

# Social sign-in (patient_app and driver_app). These are OAuth *client IDs*
# — public audience identifiers, not secrets — used to validate the `aud`
# claim on Google/Apple identity tokens. Leave a provider's list empty to
# disable it (the corresponding /patients|drivers/auth/*/ endpoint returns
# 400 until set).
GOOGLE_OAUTH_CLIENT_IDS = env.list("GOOGLE_OAUTH_CLIENT_IDS", default=[])
APPLE_SIGN_IN_CLIENT_IDS = env.list("APPLE_SIGN_IN_CLIENT_IDS", default=[])

INSTALLED_APPS = [
    "daphne",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "drf_spectacular",
    "channels",
    "django_filters",
    "apps.core",
    "apps.accounts",
    "apps.rbac",
    "apps.operations",
    "apps.patients",
    "apps.drivers",
    "apps.trips",
    "apps.facilities",
    "apps.billing",
    "apps.notifications",
    "apps.dashboard",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# ============================================
# DATABASE — PostgreSQL
# ============================================
# Render (and most PaaS providers) inject a single DATABASE_URL for the
# managed Postgres instance; local dev still uses the discrete POSTGRES_* vars.
if env("DATABASE_URL", default=""):
    DATABASES = {"default": env.db_url("DATABASE_URL")}
    # 0 (close after every request) rather than a persistent connection —
    # Render's free Postgres plan caps total connections very low, and
    # holding one open per worker thread was exhausting it under any
    # concurrent load (WS traffic + health checks + API requests), causing
    # "remaining connection slots are reserved for roles with the SUPERUSER
    # attribute" errors even on the health check itself.
    DATABASES["default"]["CONN_MAX_AGE"] = 0
    DATABASES["default"]["OPTIONS"] = {"connect_timeout": 10}
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": env("POSTGRES_DB", default="tibasafari"),
            "USER": env("POSTGRES_USER", default="tibasafari"),
            "PASSWORD": env("POSTGRES_PASSWORD", default="tibasafari"),
            "HOST": env("POSTGRES_HOST", default="localhost"),
            "PORT": env("POSTGRES_PORT", default="5432"),
            "CONN_MAX_AGE": 60,
            "OPTIONS": {
                "connect_timeout": 10,
            },
        }
    }

# ============================================
# CHANNEL LAYERS — Redis-backed WebSockets
# ============================================
# Render's managed Redis only exposes one connection string (REDIS_URL);
# CHANNEL_LAYERS_REDIS_URL lets local dev keep pointing channels at a
# separate logical DB index (redis://localhost:6379/1) from the cache (/0).
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [{
                "address": env(
                    "CHANNEL_LAYERS_REDIS_URL",
                    default=env("REDIS_URL", default="redis://localhost:6379/1"),
                ),
                "protocol": 2,
            }],
            "capacity": 1500,
            "expiry": 10,
        },
    },
}

# ============================================
# CACHE — Redis
# ============================================
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": env("REDIS_URL", default="redis://localhost:6379/0"),
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient",
            "SOCKET_CONNECT_TIMEOUT": 5,
            "SOCKET_TIMEOUT": 5,
            "CONNECTION_POOL_KWARGS": {"protocol": 2},
        },
    }
}

AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "Africa/Dar_es_Salaam"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ============================================
# EMAIL
# ============================================
EMAIL_BACKEND = env(
    "EMAIL_BACKEND",
    default="django.core.mail.backends.console.EmailBackend",
)
EMAIL_HOST = env("EMAIL_HOST", default="smtp.gmail.com")
EMAIL_PORT = env.int("EMAIL_PORT", default=587)
EMAIL_USE_TLS = env.bool("EMAIL_USE_TLS", default=True)
EMAIL_HOST_USER = env("EMAIL_HOST_USER", default="")
EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD", default="")
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", default="Tiba Safari <noreply@tibasafari.com>")

# ============================================
# REST FRAMEWORK
# ============================================
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "apps.core.exceptions.api_exception_handler",
    "DEFAULT_PAGINATION_CLASS": "apps.core.pagination.StandardResultsSetPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_THROTTLE_CLASSES": (
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ),
    "DEFAULT_THROTTLE_RATES": {
        "anon": env("ANON_THROTTLE_RATE", default="100/hour"),
        "user": env("USER_THROTTLE_RATE", default="1000/hour"),
        "email_otp": env("EMAIL_OTP_THROTTLE_RATE", default="5/hour"),
    },
    "DEFAULT_FILTER_BACKENDS": (
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ),
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=env("ACCESS_TOKEN_LIFETIME_MINUTES")),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=env("REFRESH_TOKEN_LIFETIME_DAYS")),
    "AUTH_HEADER_TYPES": ("Bearer",),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Tiba Safari API",
    "DESCRIPTION": "Backend API for NEMT (Non-Emergency Medical Transportation) operations.",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "COMPONENT_SPLIT_REQUEST": True,
    "SECURITY": [{"bearerAuth": []}],
}

# ============================================
# FARE CALCULATION CONSTANTS
# ============================================
FARE_BASE_RATE = env("FARE_BASE_RATE")
FARE_PER_KM = env("FARE_PER_KM")
FARE_PER_MINUTE = env("FARE_PER_MINUTE")
FARE_MINIMUM = env("FARE_MINIMUM")
FARE_WHEELCHAIR_SURCHARGE = env("FARE_WHEELCHAIR_SURCHARGE")

# ============================================
# SECURITY
# ============================================
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = True
X_FRAME_OPTIONS = "DENY"

if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
