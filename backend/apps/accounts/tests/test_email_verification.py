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
def test_registration_creates_unverified_user_with_no_tokens():
    client = APIClient()
    response = client.post(reverse("patient-signup"), PATIENT_SIGNUP, format="json")

    assert response.status_code == 201
    assert "access" not in response.data["data"]
    assert "refresh" not in response.data["data"]

    user = User.objects.get(email=PATIENT_SIGNUP["email"])
    assert user.is_email_verified is False
    assert len(mail.outbox) == 1
    assert user.email in mail.outbox[0].to


@pytest.mark.django_db
def test_login_blocked_until_email_verified():
    client = APIClient()
    client.post(reverse("patient-signup"), PATIENT_SIGNUP, format="json")

    response = client.post(
        reverse("auth-login"),
        {"email": PATIENT_SIGNUP["email"], "password": PATIENT_SIGNUP["password"]},
        format="json",
    )

    assert response.status_code == 403
    assert response.data["error"]["code"] == "email_not_verified"


@pytest.mark.django_db
def test_correct_code_verifies_and_unblocks_login():
    client = APIClient()
    client.post(reverse("patient-signup"), PATIENT_SIGNUP, format="json")
    user = User.objects.get(email=PATIENT_SIGNUP["email"])
    code = EmailOTP.objects.get(user=user, purpose=EmailOTP.Purpose.VERIFY_EMAIL).code

    verify_response = client.post(
        reverse("verify-email"),
        {"email": PATIENT_SIGNUP["email"], "code": code},
        format="json",
    )
    assert verify_response.status_code == 200
    user.refresh_from_db()
    assert user.is_email_verified is True

    login_response = client.post(
        reverse("auth-login"),
        {"email": PATIENT_SIGNUP["email"], "password": PATIENT_SIGNUP["password"]},
        format="json",
    )
    assert login_response.status_code == 200
    assert "access" in login_response.data["data"]


@pytest.mark.django_db
def test_wrong_or_expired_code_rejected():
    client = APIClient()
    client.post(reverse("patient-signup"), PATIENT_SIGNUP, format="json")

    wrong_response = client.post(
        reverse("verify-email"),
        {"email": PATIENT_SIGNUP["email"], "code": "000000"},
        format="json",
    )
    assert wrong_response.status_code == 400

    user = User.objects.get(email=PATIENT_SIGNUP["email"])
    otp = EmailOTP.objects.get(user=user, purpose=EmailOTP.Purpose.VERIFY_EMAIL)
    from django.utils import timezone

    otp.expires_at = timezone.now() - timezone.timedelta(minutes=1)
    otp.save(update_fields=["expires_at"])

    expired_response = client.post(
        reverse("verify-email"),
        {"email": PATIENT_SIGNUP["email"], "code": otp.code},
        format="json",
    )
    assert expired_response.status_code == 400
    user.refresh_from_db()
    assert user.is_email_verified is False


@pytest.mark.django_db
def test_code_cannot_be_reused_after_verification():
    client = APIClient()
    client.post(reverse("patient-signup"), PATIENT_SIGNUP, format="json")
    user = User.objects.get(email=PATIENT_SIGNUP["email"])
    code = EmailOTP.objects.get(user=user, purpose=EmailOTP.Purpose.VERIFY_EMAIL).code

    first = client.post(
        reverse("verify-email"), {"email": PATIENT_SIGNUP["email"], "code": code}, format="json"
    )
    assert first.status_code == 200

    second = client.post(
        reverse("verify-email"), {"email": PATIENT_SIGNUP["email"], "code": code}, format="json"
    )
    assert second.status_code == 400


@pytest.mark.django_db
def test_resend_verification_generates_new_email():
    client = APIClient()
    client.post(reverse("patient-signup"), PATIENT_SIGNUP, format="json")
    mail.outbox.clear()

    response = client.post(
        reverse("resend-verification"), {"email": PATIENT_SIGNUP["email"]}, format="json"
    )
    assert response.status_code == 200
    assert len(mail.outbox) == 1


@pytest.mark.django_db
def test_resend_verification_does_not_leak_unknown_email():
    client = APIClient()
    response = client.post(
        reverse("resend-verification"), {"email": "nobody@example.com"}, format="json"
    )
    assert response.status_code == 200
    assert len(mail.outbox) == 0


@pytest.mark.django_db
def test_resend_verification_respects_throttle(monkeypatch):
    # SimpleRateThrottle.THROTTLE_RATES is bound from api_settings once at
    # import time, so overriding settings.REST_FRAMEWORK at runtime doesn't
    # reach it — patch the (mutable, shared) dict entry directly instead.
    monkeypatch.setitem(EmailOTPRequestThrottle.THROTTLE_RATES, "email_otp", "2/hour")
    client = APIClient()
    client.post(reverse("patient-signup"), PATIENT_SIGNUP, format="json")  # uses 1

    ok = client.post(
        reverse("resend-verification"), {"email": PATIENT_SIGNUP["email"]}, format="json"
    )  # uses 2
    assert ok.status_code == 200

    throttled = client.post(
        reverse("resend-verification"), {"email": PATIENT_SIGNUP["email"]}, format="json"
    )
    assert throttled.status_code == 429


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
def test_social_created_account_defaults_verified_and_can_log_in():
    # Mirrors PatientService.find_or_create_social_patient: no
    # is_email_verified kwarg passed, so it must fall back to the model
    # default (True) rather than inheriting patient self-signup's False.
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
