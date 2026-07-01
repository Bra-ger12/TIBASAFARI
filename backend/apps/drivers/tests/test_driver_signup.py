import pytest
from django.urls import reverse
from rest_framework.test import APIClient

from apps.drivers.models import DriverProfile
from apps.rbac.permissions import has_role


@pytest.mark.django_db
def test_driver_signup_creates_login_ready_driver_account():
    client = APIClient()

    signup_response = client.post(
        reverse("driver-signup"),
        {
            "full_name": "Juma Driver",
            "email": "juma.driver@example.com",
            "phone_number": "+255712345678",
            "license_number": "DRV-12345",
            "vehicle_registration": "T 123 ABC",
            "password": "secret123",
            "confirm_password": "secret123",
        },
        format="json",
    )

    assert signup_response.status_code == 201
    profile = DriverProfile.objects.select_related("user", "vehicle").get(
        user__email="juma.driver@example.com",
    )
    assert profile.user.is_active is True
    assert profile.user.status == "active"
    assert profile.license_number == "DRV-12345"
    assert profile.vehicle.registration_number == "T 123 ABC"
    assert has_role(profile.user, "DRIVER") is True

    login_response = client.post(
        reverse("auth-login"),
        {"email": "juma.driver@example.com", "password": "secret123"},
        format="json",
    )

    assert login_response.status_code == 200
    access = login_response.data["data"]["access"]

    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    profile_response = client.get("/api/v1/drivers/profiles/me/")

    assert profile_response.status_code == 200
    assert profile_response.data["data"]["user_email"] == "juma.driver@example.com"
