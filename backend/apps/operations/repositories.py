from apps.operations.models import Vehicle


class VehicleRepository:
    model = Vehicle

    def list(self):
        return self.model.objects.all()

    def create(self, **data):
        return self.model.objects.create(**data)

    def update(self, instance, **data):
        for field, value in data.items():
            setattr(instance, field, value)
        instance.save(update_fields=[*data.keys(), "updated_at"])
        return instance
