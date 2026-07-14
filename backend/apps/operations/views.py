from rest_framework import filters, viewsets

from apps.operations.models import Vehicle, VehicleExpense
from apps.operations.serializers import VehicleExpenseSerializer, VehicleSerializer
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


class VehicleExpenseViewSet(viewsets.ModelViewSet):
    queryset = VehicleExpense.objects.select_related("vehicle", "recorded_by")
    serializer_class = VehicleExpenseSerializer
    permission_classes = [HasPermission]
    filter_backends = [filters.OrderingFilter]
    ordering_fields = ["incurred_at", "amount", "created_at"]
    permission_map = {
        "list": "operations.view_vehicle",
        "retrieve": "operations.view_vehicle",
        "create": "operations.manage_vehicle",
        "update": "operations.manage_vehicle",
        "partial_update": "operations.manage_vehicle",
        "destroy": "operations.manage_vehicle",
    }

    def get_queryset(self):
        queryset = super().get_queryset()
        vehicle_id = self.request.query_params.get("vehicle")
        if vehicle_id:
            queryset = queryset.filter(vehicle_id=vehicle_id)
        start = self.request.query_params.get("start")
        if start:
            queryset = queryset.filter(incurred_at__gte=start)
        end = self.request.query_params.get("end")
        if end:
            queryset = queryset.filter(incurred_at__lte=end)
        return queryset

    def perform_create(self, serializer):
        serializer.save(recorded_by=self.request.user)
