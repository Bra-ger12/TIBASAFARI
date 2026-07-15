import pytest

from apps.accounts.models import User
from apps.drivers.models import DriverProfile
from apps.drivers.serializers import DriverProfileSerializer
from apps.operations.models import Vehicle


def _make_user(email, full_name="Test Driver"):
    return User.objects.create_user(
        email=email,
        password="StrongPass123",
        full_name=full_name,
        status=User.Status.ACTIVE,
        is_active=True,
    )


def _make_vehicle(registration_number="T 999 ZZZ"):
    return Vehicle.objects.create(
        registration_number=registration_number,
        make="Toyota",
        model="Hiace",
        year=2022,
    )


@pytest.mark.django_db
def test_cannot_assign_vehicle_already_assigned_to_another_driver():
    vehicle = _make_vehicle()
    driver_a = _make_user("drivera@example.com")
    DriverProfile.objects.create(
        user=driver_a, license_number="LIC-A", vehicle=vehicle
    )
    driver_b = _make_user("driverb@example.com")
    profile_b = DriverProfile.objects.create(user=driver_b, license_number="LIC-B")

    serializer = DriverProfileSerializer(
        profile_b, data={"vehicle": str(vehicle.id)}, partial=True
    )

    assert not serializer.is_valid()
    assert "vehicle" in serializer.errors


@pytest.mark.django_db
def test_can_reassign_same_vehicle_to_same_driver():
    vehicle = _make_vehicle()
    driver = _make_user("driverc@example.com")
    profile = DriverProfile.objects.create(
        user=driver, license_number="LIC-C", vehicle=vehicle
    )

    serializer = DriverProfileSerializer(
        profile, data={"vehicle": str(vehicle.id)}, partial=True
    )

    assert serializer.is_valid(), serializer.errors
