import pytest
from django.urls import reverse
from rest_framework.test import APIClient

from apps.accounts.models import User


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
