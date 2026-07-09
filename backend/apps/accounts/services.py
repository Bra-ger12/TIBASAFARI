from django.contrib.auth import authenticate
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils import timezone
from django.utils.crypto import get_random_string
from rest_framework import exceptions
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.exceptions import EmailNotVerified
from apps.accounts.models import EmailOTP
from apps.accounts.repositories import UserRepository

_OTP_TTL_MINUTES = 30


class EmailOTPService:
    """Generates and checks the 6-digit codes emailed to patients for
    self-service email verification and password reset."""

    def generate(self, user, *, purpose: str) -> str:
        code = get_random_string(6, allowed_chars="0123456789")
        EmailOTP.objects.create(
            user=user,
            purpose=purpose,
            code=code,
            expires_at=timezone.now() + timezone.timedelta(minutes=_OTP_TTL_MINUTES),
        )
        return code

    def verify(self, user, *, purpose: str, code: str) -> bool:
        otp = (
            EmailOTP.objects.filter(
                user=user, purpose=purpose, code=code, consumed_at__isnull=True
            )
            .order_by("-created_at")
            .first()
        )
        if otp is None or not otp.is_valid:
            return False
        otp.consumed_at = timezone.now()
        otp.save(update_fields=["consumed_at"])
        return True

    def send_verification_email(self, user, code: str):
        self._send(
            user,
            subject="Verify your TibaSafari email",
            template_name="verification_code",
            context={"code": code, "full_name": user.full_name, "ttl_minutes": _OTP_TTL_MINUTES},
        )

    def send_password_reset_email(self, user, code: str):
        self._send(
            user,
            subject="Your TibaSafari password reset code",
            template_name="password_reset_code",
            context={"code": code, "full_name": user.full_name, "ttl_minutes": _OTP_TTL_MINUTES},
        )

    def _send(self, user, *, subject: str, template_name: str, context: dict):
        text_body = render_to_string(f"emails/{template_name}.txt", context)
        html_body = render_to_string(f"emails/{template_name}.html", context)
        message = EmailMultiAlternatives(subject=subject, body=text_body, to=[user.email])
        message.attach_alternative(html_body, "text/html")
        message.send()


class AuthService:
    def login(self, *, email: str, password: str):
        user = authenticate(email=email, password=password)
        if user is None:
            raise exceptions.AuthenticationFailed("Invalid email or password")
        if not user.is_email_verified:
            raise EmailNotVerified()
        if not user.is_approved:
            raise exceptions.PermissionDenied("Account is not active")

        refresh = RefreshToken.for_user(user)
        refresh["roles"] = list(
            user.role_assignments.values_list("role__code", flat=True)
        )
        return {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "user": user,
        }


class UserService:
    repository = UserRepository()

    def register_admin(self, *, email, password, full_name, phone_number=""):
        existing = self.repository.get_by_email(email)
        if existing:
            raise exceptions.ValidationError({"email": "Email is already registered"})
        return self.repository.create(
            email=email,
            password=password,
            full_name=full_name,
            phone_number=phone_number,
            is_active=False,
        )
