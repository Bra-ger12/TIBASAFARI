import pytest
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import EmailOTP, User
from apps.accounts.services import EmailOTPService


@pytest.mark.django_db
def test_admin_signup_creates_pending_inactive_user():
    client = APIClient()
    response = client.post(
        reverse("admin-signup"),
        {
            "full_name": "Asha Mkama",
            "email": "asha@example.com",
            "phone_number": "+255712345678",
            "password": "StrongPass123",
            "confirm_password": "StrongPass123",
        },
        format="json",
    )

    assert response.status_code == 201
    user = User.objects.get(email="asha@example.com")
    assert user.status == User.Status.PENDING
    assert user.is_active is False


@pytest.mark.django_db
def test_login_returns_jwt_for_active_user():
    user = User.objects.create_user(
        email="admin@example.com",
        password="StrongPass123",
        full_name="Admin User",
        status=User.Status.ACTIVE,
        is_active=True,
    )
    client = APIClient()

    response = client.post(
        reverse("auth-login"),
        {"email": user.email, "password": "StrongPass123"},
        format="json",
    )

    assert response.status_code == 200
    assert response.data["success"] is True
    assert "access" in response.data["data"]
    assert response.data["data"]["user"]["email"] == user.email


@pytest.mark.django_db
def test_change_password_blacklists_existing_refresh_tokens():
    """Regression test: changing your password used to leave every
    already-issued refresh token valid forever — a leaked old password's
    session could keep minting new access tokens indefinitely even after
    the real owner changed it."""
    user = User.objects.create_user(
        email="changepw@example.com",
        password="OldPass123",
        full_name="Change PW User",
        status=User.Status.ACTIVE,
        is_active=True,
    )
    old_refresh = RefreshToken.for_user(user)
    assert OutstandingToken.objects.filter(user=user).exists()
    assert not BlacklistedToken.objects.filter(token__user=user).exists()

    client = APIClient()
    client.force_authenticate(user=user)
    response = client.post(
        reverse("change-password"),
        {"current_password": "OldPass123", "new_password": "NewPass456"},
        format="json",
    )

    assert response.status_code == 200
    assert BlacklistedToken.objects.filter(token__user=user).exists()
    # check_blacklist() raises TokenError once the token is blacklisted;
    # it's a no-op (returns None) for a still-valid token.
    with pytest.raises(Exception):
        old_refresh.check_blacklist()


@pytest.mark.django_db
def test_password_reset_confirm_blacklists_existing_refresh_tokens():
    user = User.objects.create_user(
        email="resetpw@example.com",
        password="OldPass123",
        full_name="Reset PW User",
        status=User.Status.ACTIVE,
        is_active=True,
    )
    RefreshToken.for_user(user)
    assert OutstandingToken.objects.filter(user=user).exists()

    code = EmailOTPService().generate(user, purpose=EmailOTP.Purpose.PASSWORD_RESET)
    client = APIClient()
    response = client.post(
        reverse("password-reset-confirm"),
        {"email": user.email, "code": code, "new_password": "NewPass456"},
        format="json",
    )

    assert response.status_code == 200
    assert BlacklistedToken.objects.filter(token__user=user).exists()
