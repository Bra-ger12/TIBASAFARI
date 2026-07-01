import pytest
from rest_framework.test import APIRequestFactory

from apps.accounts.models import User
from apps.rbac.models import Permission, Role, UserRole
from apps.rbac.permissions import HasPermission


class DummyView:
    required_permission = "operations.view_vehicle"


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
