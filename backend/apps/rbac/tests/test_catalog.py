import pytest

from apps.rbac.catalog import ROLES, sync_role
from apps.patients.services import get_or_create_patient_role


@pytest.mark.django_db
def test_sync_role_grants_full_canonical_permission_set():
    for code, expected in ROLES.items():
        role = sync_role(code)
        granted = set(role.permissions.values_list("code", flat=True))
        assert granted == set(expected["permissions"]), (
            f"{code} role permissions drifted from apps.rbac.catalog.ROLES"
        )


@pytest.mark.django_db
def test_patient_signup_role_includes_cancel_and_chat_permissions():
    """Regression test: patient signup used to grant a smaller permission
    set than seed_rbac.py, silently breaking Cancel Ride (cancel_trip)
    and in-app chat (trip_messages) for every real patient account."""
    role = get_or_create_patient_role()
    granted = set(role.permissions.values_list("code", flat=True))
    assert "cancel_trip" in granted
    assert "trip_messages" in granted


@pytest.mark.django_db
def test_sync_role_is_idempotent_and_self_healing():
    """Calling sync_role again after permissions were manually messed with
    must restore the canonical set exactly (no partial/stale state)."""
    role = sync_role("DRIVER")
    role.permissions.clear()
    assert role.permissions.count() == 0

    role = sync_role("DRIVER")
    granted = set(role.permissions.values_list("code", flat=True))
    assert granted == set(ROLES["DRIVER"]["permissions"])
