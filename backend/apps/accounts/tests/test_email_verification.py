import pytest
from django.core import mail
from django.core.cache import cache
from django.urls import reverse
from rest_framework.test import APIClient

from apps.accounts.models import EmailOTP, User
from apps.core.throttles import EmailOTPRequestThrottle

PATIENT_SIGNUP = {
    "full_name": "Amina Patient",
    "email": "amina.patient@example.com",
    "phone_number": "+255712345678",
    "password": "StrongPass123",
    "confirm_password": "StrongPass123",
}


@pytest.fixture(autouse=True)
def _clear_throttle_cache():
    # ScopedRateThrottle keys off IP for anonymous requests and persists in
    # the process-wide cache across tests in the same run — reset it so
    # tests in this file don't throttle each other out.
    cache.clear()


@pytest.mark.django_db
def test_registration_signs_the_patient_in_immediately():
    # No email-verification step: patient signup returns a usable session
    # right away instead of requiring a code round-trip first.
    client = APIClient()
    response = client.post(reverse("patient-signup"), PATIENT_SIGNUP, format="json")

    assert response.status_code == 201
    assert "access" in response.data["data"]
    assert "refresh" in response.data["data"]

    user = User.objects.get(email=PATIENT_SIGNUP["email"])
    assert user.is_email_verified is True


@pytest.mark.django_db
def test_can_log_in_right_after_registration():
    client = APIClient()
    client.post(reverse("patient-signup"), PATIENT_SIGNUP, format="json")

    response = client.post(
        reverse("auth-login"),
        {"email": PATIENT_SIGNUP["email"], "password": PATIENT_SIGNUP["password"]},
        format="json",
    )
    assert response.status_code == 200
    assert "access" in response.data["data"]


@pytest.mark.django_db
def test_password_reset_round_trip():
    user = User.objects.create_user(
        email="reset.me@example.com",
        password="OldPass123",
        full_name="Reset Me",
        status=User.Status.ACTIVE,
        is_active=True,
    )
    client = APIClient()

    request_response = client.post(
        reverse("password-reset"), {"email": user.email}, format="json"
    )
    assert request_response.status_code == 200
    assert len(mail.outbox) == 1

    code = EmailOTP.objects.get(user=user, purpose=EmailOTP.Purpose.PASSWORD_RESET).code
    confirm_response = client.post(
        reverse("password-reset-confirm"),
        {"email": user.email, "code": code, "new_password": "NewPass456"},
        format="json",
    )
    assert confirm_response.status_code == 200

    login_response = client.post(
        reverse("auth-login"),
        {"email": user.email, "password": "NewPass456"},
        format="json",
    )
    assert login_response.status_code == 200


@pytest.mark.django_db
def test_password_reset_request_does_not_leak_unknown_email():
    client = APIClient()
    response = client.post(
        reverse("password-reset"), {"email": "nobody@example.com"}, format="json"
    )
    assert response.status_code == 200
    assert len(mail.outbox) == 0


@pytest.mark.django_db
def test_password_reset_code_locked_out_after_max_wrong_attempts():
    """Regression test: EmailOTPService.verify() used to have no cap on
    wrong guesses for a still-valid code — a 6-digit code could be
    brute-forced given enough attempts within its 30-minute validity
    window."""
    user = User.objects.create_user(
        email="reset.me@example.com",
        password="OldPass123",
        full_name="Reset Me",
        status=User.Status.ACTIVE,
        is_active=True,
    )
    client = APIClient()
    client.post(reverse("password-reset"), {"email": user.email}, format="json")
    otp = EmailOTP.objects.get(user=user, purpose=EmailOTP.Purpose.PASSWORD_RESET)

    for _ in range(5):
        response = client.post(
            reverse("password-reset-confirm"),
            {"email": user.email, "code": "000000", "new_password": "NewPass456"},
            format="json",
        )
        assert response.status_code == 400

    otp.refresh_from_db()
    assert otp.attempts == 5

    # Even the real code is now rejected — the code is locked out, not just
    # the specific wrong guesses.
    correct_response = client.post(
        reverse("password-reset-confirm"),
        {"email": user.email, "code": otp.code, "new_password": "NewPass456"},
        format="json",
    )
    assert correct_response.status_code == 400


@pytest.mark.django_db
def test_password_reset_code_cannot_be_reused():
    user = User.objects.create_user(
        email="reset.me@example.com",
        password="OldPass123",
        full_name="Reset Me",
        status=User.Status.ACTIVE,
        is_active=True,
    )
    client = APIClient()
    client.post(reverse("password-reset"), {"email": user.email}, format="json")
    code = EmailOTP.objects.get(user=user, purpose=EmailOTP.Purpose.PASSWORD_RESET).code

    first = client.post(
        reverse("password-reset-confirm"),
        {"email": user.email, "code": code, "new_password": "NewPass456"},
        format="json",
    )
    assert first.status_code == 200

    second = client.post(
        reverse("password-reset-confirm"),
        {"email": user.email, "code": code, "new_password": "AnotherPass789"},
        format="json",
    )
    assert second.status_code == 400


@pytest.mark.django_db
def test_password_reset_request_respects_throttle(monkeypatch):
    # SimpleRateThrottle.THROTTLE_RATES is bound from api_settings once at
    # import time, so overriding settings.REST_FRAMEWORK at runtime doesn't
    # reach it — patch the (mutable, shared) dict entry directly instead.
    monkeypatch.setitem(EmailOTPRequestThrottle.THROTTLE_RATES, "email_otp", "1/hour")
    user = User.objects.create_user(
        email="reset.me@example.com",
        password="OldPass123",
        full_name="Reset Me",
        status=User.Status.ACTIVE,
        is_active=True,
    )
    client = APIClient()

    ok = client.post(reverse("password-reset"), {"email": user.email}, format="json")  # uses 1
    assert ok.status_code == 200

    throttled = client.post(reverse("password-reset"), {"email": user.email}, format="json")
    assert throttled.status_code == 429


@pytest.mark.django_db
def test_social_created_account_defaults_verified_and_can_log_in():
    # Mirrors PatientService.find_or_create_social_patient: no
    # is_email_verified kwarg passed, so it must fall back to the model
    # default (True).
    user = User.objects.create_user(
        email="social@example.com",
        password="SocialPass123",
        full_name="Social User",
        status=User.Status.ACTIVE,
        is_active=True,
    )
    assert user.is_email_verified is True

    client = APIClient()
    login_response = client.post(
        reverse("auth-login"),
        {"email": user.email, "password": "SocialPass123"},
        format="json",
    )
    assert login_response.status_code == 200
    assert "access" in login_response.data["data"]
