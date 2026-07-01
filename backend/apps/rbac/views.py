from rest_framework import viewsets

from apps.rbac.models import Permission, Role, RolePermission, UserRole
from apps.rbac.permissions import HasPermission
from apps.rbac.serializers import (
    PermissionSerializer,
    RolePermissionSerializer,
    RoleSerializer,
    UserRoleSerializer,
)


class PermissionViewSet(viewsets.ModelViewSet):
    queryset = Permission.objects.all()
    serializer_class = PermissionSerializer
    permission_classes = [HasPermission]
    permission_map = {
        "list": "rbac.view_permission",
        "retrieve": "rbac.view_permission",
        "create": "rbac.manage_permission",
        "update": "rbac.manage_permission",
        "partial_update": "rbac.manage_permission",
        "destroy": "rbac.manage_permission",
    }


class RoleViewSet(viewsets.ModelViewSet):
    queryset = Role.objects.prefetch_related("permissions").all()
    serializer_class = RoleSerializer
    permission_classes = [HasPermission]
    permission_map = {
        "list": "rbac.view_role",
        "retrieve": "rbac.view_role",
        "create": "rbac.manage_role",
        "update": "rbac.manage_role",
        "partial_update": "rbac.manage_role",
        "destroy": "rbac.manage_role",
    }


class UserRoleViewSet(viewsets.ModelViewSet):
    queryset = UserRole.objects.select_related("user", "role").all()
    serializer_class = UserRoleSerializer
    permission_classes = [HasPermission]
    permission_map = {
        "list": "rbac.view_user_role",
        "retrieve": "rbac.view_user_role",
        "create": "rbac.assign_role",
        "update": "rbac.assign_role",
        "partial_update": "rbac.assign_role",
        "destroy": "rbac.assign_role",
    }


class RolePermissionViewSet(viewsets.ModelViewSet):
    queryset = RolePermission.objects.select_related("role", "permission").all()
    serializer_class = RolePermissionSerializer
    permission_classes = [HasPermission]
    permission_map = {
        "list": "rbac.view_role",
        "retrieve": "rbac.view_role",
        "create": "rbac.manage_role",
        "update": "rbac.manage_role",
        "partial_update": "rbac.manage_role",
        "destroy": "rbac.manage_role",
    }
