import uuid

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone

from apps.accounts.managers import UserManager


class User(AbstractUser):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        ACTIVE = "active", "Active"
        SUSPENDED = "suspended", "Suspended"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    username = models.CharField(max_length=150, unique=True, blank=True, null=True)
    full_name = models.CharField(max_length=150)
    phone = models.CharField(max_length=32, blank=True)
    phone_number = models.CharField(max_length=32, blank=True)
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.PENDING,
    )
    # Defaults True so every existing account, plus every non-self-service
    # creation path (admin signup, driver signup, Google/Apple social
    # sign-in), is unaffected. Only PatientSignupSerializer sets this False.
    is_email_verified = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["full_name"]

    objects = UserManager()

    def __str__(self) -> str:
        return self.email

    def save(self, *args, **kwargs):
        if not self.username:
            self.username = self.email
        if not self.phone and self.phone_number:
            self.phone = self.phone_number
        if not self.phone_number and self.phone:
            self.phone_number = self.phone
        super().save(*args, **kwargs)

    @property
    def is_approved(self) -> bool:
        return self.is_active and self.status == self.Status.ACTIVE


class EmailOTP(models.Model):
    """Short-lived 6-digit codes emailed to patients for self-service email
    verification and password reset — chosen over a clickable link since
    patient_app is mobile-only (no web page to land on, and setting up
    Universal Links / App Links for a deep link is unnecessary complexity)."""

    class Purpose(models.TextChoices):
        VERIFY_EMAIL = "VERIFY_EMAIL", "Verify Email"
        PASSWORD_RESET = "PASSWORD_RESET", "Password Reset"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, related_name="otp_codes", on_delete=models.CASCADE
    )
    purpose = models.CharField(max_length=20, choices=Purpose.choices)
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    consumed_at = models.DateTimeField(null=True, blank=True)
    attempts = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self) -> str:
        return f"EmailOTP({self.user_id}, {self.purpose})"

    @property
    def is_valid(self) -> bool:
        return self.consumed_at is None and timezone.now() < self.expires_at
