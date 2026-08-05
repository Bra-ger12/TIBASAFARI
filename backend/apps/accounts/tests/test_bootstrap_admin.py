from io import StringIO

import pytest
from django.core.management import call_command

from apps.accounts.models import User


@pytest.mark.django_db
def test_bootstrap_admin_skips_without_credentials():
    out = StringIO()

    call_command("bootstrap_admin", stdout=out)

    assert "skipped" in out.getvalue().lower()
    assert User.objects.count() == 0


@pytest.mark.django_db
def test_bootstrap_admin_creates_active_superuser():
    out = StringIO()

    call_command(
        "bootstrap_admin",
        email="kbraytonroger@gmail.com",
        password="Brayton123",
        full_name="Brayton Roger",
        phone_number="+255712345678",
        stdout=out,
    )

    user = User.objects.get(email="kbraytonroger@gmail.com")
    assert user.is_active is True
    assert user.is_staff is True
    assert user.is_superuser is True
    assert user.status == User.Status.ACTIVE
    assert user.full_name == "Brayton Roger"
    assert user.phone_number == "+255712345678"
    assert user.check_password("Brayton123") is True
    assert "created admin bootstrap account" in out.getvalue().lower()


@pytest.mark.django_db
def test_bootstrap_admin_upgrades_existing_user():
    user = User.objects.create_user(
        email="kbraytonroger@gmail.com",
        password="OldPass123",
        full_name="Old Name",
        status=User.Status.PENDING,
        is_active=False,
    )

    call_command(
        "bootstrap_admin",
        email="kbraytonroger@gmail.com",
        password="Brayton123",
        full_name="Brayton Roger",
    )

    user.refresh_from_db()
    assert user.is_active is True
    assert user.is_staff is True
    assert user.is_superuser is True
    assert user.status == User.Status.ACTIVE
    assert user.full_name == "Brayton Roger"
    assert user.check_password("Brayton123") is True
