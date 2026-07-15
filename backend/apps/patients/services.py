from django.db import transaction

from apps.accounts.models import User
from apps.patients.models import PatientProfile
from apps.rbac.catalog import sync_role
from apps.rbac.models import Role, UserRole


def get_or_create_patient_role() -> Role:
    # Delegates to the canonical role/permission catalog (apps.rbac.catalog)
    # so patient signup can never grant a different permission set than
    # the seed_rbac management command — previously this function was
    # missing cancel_trip/trip_messages, silently breaking "Cancel Ride"
    # and in-app chat for every real patient account.
    return sync_role("PATIENT")


class PatientService:
    def create_profile(self, *, user, **data):
        return PatientProfile.objects.create(user=user, **data)

    def update_profile(self, profile, **data):
        for field, value in data.items():
            setattr(profile, field, value)
        profile.save()
        return profile

    @transaction.atomic
    def find_or_create_social_patient(self, *, email: str, full_name: str | None) -> User:
        """Used by Google/Apple sign-in: returns the existing user for this
        email, or creates a new PATIENT account (no usable password — social
        sign-in is the only way in until they set one)."""
        email = email.strip().lower()
        user = User.objects.filter(email__iexact=email).first()
        if user is not None:
            return user

        user = User.objects.create_user(
            email=email,
            password=None,
            full_name=full_name or email.split("@")[0],
            status=User.Status.ACTIVE,
            is_active=True,
        )
        UserRole.objects.get_or_create(user=user, role=get_or_create_patient_role())
        PatientProfile.objects.create(user=user)
        return user

