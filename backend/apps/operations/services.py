from rest_framework import exceptions

from apps.operations.repositories import VehicleRepository


class VehicleService:
    repository = VehicleRepository()

    def create_vehicle(self, **data):
        registration = data["registration_number"].upper().strip()
        if self.repository.model.objects.filter(
            registration_number__iexact=registration,
        ).exists():
            raise exceptions.ValidationError(
                {"registration_number": "Vehicle already exists"}
            )
        data["registration_number"] = registration
        return self.repository.create(**data)

    def update_vehicle(self, vehicle, **data):
        if "registration_number" in data:
            data["registration_number"] = data["registration_number"].upper().strip()
        return self.repository.update(vehicle, **data)
