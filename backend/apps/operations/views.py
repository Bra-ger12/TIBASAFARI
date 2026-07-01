from rest_framework import viewsets

from apps.operations.models import Vehicle
from apps.operations.serializers import VehicleSerializer
from apps.operations.services import VehicleService
from apps.rbac.permissions import HasPermission


class VehicleViewSet(viewsets.ModelViewSet):
    queryset = Vehicle.objects.all()
    serializer_class = VehicleSerializer
    permission_classes = [HasPermission]
    service = VehicleService()
    permission_map = {
        "list": "operations.view_vehicle",
        "retrieve": "operations.view_vehicle",
        "create": "operations.manage_vehicle",
        "update": "operations.manage_vehicle",
        "partial_update": "operations.manage_vehicle",
        "destroy": "operations.manage_vehicle",
    }

    def perform_create(self, serializer):
        vehicle = self.service.create_vehicle(**serializer.validated_data)
        serializer.instance = vehicle

    def perform_update(self, serializer):
        vehicle = self.service.update_vehicle(
            serializer.instance,
            **serializer.validated_data,
        )
        serializer.instance = vehicle
