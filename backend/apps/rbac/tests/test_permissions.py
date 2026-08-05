import pytest
from rest_framework.test import APIRequestFactory

from apps.accounts.models import User
from apps.patients.models import PatientProfile
from apps.rbac.models import Permission, Role, UserRole
from apps.rbac.permissions import HasPermission


class DummyView:
    required_permission = "operations.view_vehicle"


class PatientTripView:
    required_permission = "create_trip"


@pytest.mark.django_db
def test_has_permission_allows_assigned_role_permission():
    permission = Permission.objects.create(
        code="operations.view_vehicle",
        name="View vehicles",
    )
    role = Role.objects.create(code="operations_manager", name="Operations Manager")
    role.permissions.add(permission)
    user = User.objects.create_user(
        email="ops@example.com",
        password="StrongPass123",
        full_name="Ops Manager",
        status=User.Status.ACTIVE,
    )
    UserRole.objects.create(user=user, role=role)

    request = APIRequestFactory().get("/api/v1/operations/vehicles/")
    request.user = user

    assert HasPermission().has_permission(request, DummyView()) is True


@pytest.mark.django_db
def test_has_permission_denies_missing_permission():
    user = User.objects.create_user(
        email="viewer@example.com",
        password="StrongPass123",
        full_name="Viewer User",
        status=User.Status.ACTIVE,
    )
    request = APIRequestFactory().get("/api/v1/operations/vehicles/")
    request.user = user

    assert HasPermission().has_permission(request, DummyView()) is False


@pytest.mark.django_db
def test_has_permission_backfills_patient_role_for_profiled_user():
    user = User.objects.create_user(
        email="patient-roleless@example.com",
        password="StrongPass123",
        full_name="Roleless Patient",
        status=User.Status.ACTIVE,
    )
    PatientProfile.objects.create(user=user)

    request = APIRequestFactory().post("/api/v1/patients/trip-requests/")
    request.user = user

    assert HasPermission().has_permission(request, PatientTripView()) is True
    assert UserRole.objects.filter(user=user, role__code="PATIENT").exists()


@pytest.mark.django_db
def test_has_permission_does_not_grant_patient_role_without_profile():
    user = User.objects.create_user(
        email="not-a-patient@example.com",
        password="StrongPass123",
        full_name="Not Patient",
        status=User.Status.ACTIVE,
    )

    request = APIRequestFactory().post("/api/v1/patients/trip-requests/")
    request.user = user

    assert HasPermission().has_permission(request, PatientTripView()) is False
    assert not UserRole.objects.filter(user=user, role__code="PATIENT").exists()
