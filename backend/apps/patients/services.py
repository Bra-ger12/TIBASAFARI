from django.db import transaction

from apps.accounts.models import User
from apps.patients.models import PatientProfile
from apps.rbac.models import Permission, Role, UserRole

_PATIENT_PERMISSIONS = {
    "create_trip": "Create trip",
    "view_own_trips": "View own trips",
    "view_own_profile": "View own profile",
    "view_notifications": "View notifications",
}


def get_or_create_patient_role() -> Role:
    role, _ = Role.objects.get_or_create(
        code="PATIENT",
        defaults={"name": "Patient", "description": "Patient user"},
    )
    for code, name in _PATIENT_PERMISSIONS.items():
        perm, _ = Permission.objects.get_or_create(code=code, defaults={"name": name})
        role.permissions.add(perm)
    return role


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

