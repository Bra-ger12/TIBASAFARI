import pytest

from apps.operations.models import Vehicle
from apps.operations.serializers import VehicleExpenseSerializer


def _make_vehicle():
    return Vehicle.objects.create(
        registration_number="T 111 AAA",
        make="Toyota",
        model="Hiace",
        year=2022,
    )


@pytest.mark.django_db
def test_rejects_negative_amount():
    vehicle = _make_vehicle()
    serializer = VehicleExpenseSerializer(
        data={
            "vehicle": str(vehicle.id),
            "category": "MAINTENANCE",
            "amount": "-10.00",
            "incurred_at": "2026-01-01",
        }
    )
    assert not serializer.is_valid()
    assert "amount" in serializer.errors


@pytest.mark.django_db
def test_rejects_zero_amount():
    vehicle = _make_vehicle()
    serializer = VehicleExpenseSerializer(
        data={
            "vehicle": str(vehicle.id),
            "category": "MAINTENANCE",
            "amount": "0.00",
            "incurred_at": "2026-01-01",
        }
    )
    assert not serializer.is_valid()
    assert "amount" in serializer.errors


@pytest.mark.django_db
def test_accepts_positive_amount():
    vehicle = _make_vehicle()
    serializer = VehicleExpenseSerializer(
        data={
            "vehicle": str(vehicle.id),
            "category": "MAINTENANCE",
            "amount": "150.00",
            "incurred_at": "2026-01-01",
        }
    )
    assert serializer.is_valid(), serializer.errors
