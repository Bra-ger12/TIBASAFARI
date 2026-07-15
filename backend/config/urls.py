from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework_simplejwt.views import TokenRefreshView

from apps.accounts.views import (
    ChangePasswordView,
    LoginView,
    LogoutView,
    PasswordResetConfirmView,
    PasswordResetRequestView,
    ProfileView,
    ResendVerificationView,
    VerifyEmailView,
)
from apps.core.views import HealthCheckView, SecureMediaView

api_patterns = [
    path("health/", HealthCheckView.as_view(), name="health"),
    path("auth/login/", LoginView.as_view(), name="auth-login"),
    path("auth/logout/", LogoutView.as_view(), name="auth-logout"),
    path("auth/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("auth/change-password/", ChangePasswordView.as_view(), name="change-password"),
    path("auth/password-reset/", PasswordResetRequestView.as_view(), name="password-reset"),
    path(
        "auth/password-reset/confirm/",
        PasswordResetConfirmView.as_view(),
        name="password-reset-confirm",
    ),
    path("auth/verify-email/", VerifyEmailView.as_view(), name="verify-email"),
    path(
        "auth/resend-verification/",
        ResendVerificationView.as_view(),
        name="resend-verification",
    ),
    path("auth/profile/", ProfileView.as_view(), name="user-profile"),
    path("accounts/", include("apps.accounts.urls")),
    path("rbac/", include("apps.rbac.urls")),
    path("operations/", include("apps.operations.urls")),
    path("patients/", include("apps.patients.urls")),
    path("drivers/", include("apps.drivers.urls")),
    path("trips/", include("apps.trips.urls")),
    path("facilities/", include("apps.facilities.urls")),
    path("notifications/", include("apps.notifications.urls")),
    path("billing/", include("apps.billing.urls")),
    path("dashboard/", include("apps.dashboard.urls")),
]

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include(api_patterns)),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
    # Uploaded documents (patient medical records, driver licenses, trip
    # signatures/photos) contain PII and are never served under the raw
    # MEDIA_URL prefix — only via a short-lived signed token handed out by
    # an already-authorized API response. See apps.core.media/views.
    # Note: Render's disk is ephemeral — uploads still don't survive a redeploy.
    path("secure-media/<str:token>/", SecureMediaView.as_view(), name="secure-media"),
]
