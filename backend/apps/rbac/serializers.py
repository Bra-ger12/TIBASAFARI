from rest_framework import serializers

from apps.rbac.models import Permission, Role, RolePermission, UserRole


class PermissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Permission
        fields = ("id", "code", "name", "description")


class RoleSerializer(serializers.ModelSerializer):
    permission_codes = serializers.SlugRelatedField(
        many=True,
        slug_field="code",
        queryset=Permission.objects.all(),
        source="permissions",
        required=False,
    )

    class Meta:
        model = Role
        fields = (
            "id",
            "code",
            "name",
            "description",
            "permission_codes",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class UserRoleSerializer(serializers.ModelSerializer):
    role_code = serializers.SlugRelatedField(
        slug_field="code",
        queryset=Role.objects.all(),
        source="role",
    )

    class Meta:
        model = UserRole
        fields = ("id", "user", "role_code", "assigned_at")
        read_only_fields = ("id", "assigned_at")


class RolePermissionSerializer(serializers.ModelSerializer):
    role_code = serializers.SlugRelatedField(
        slug_field="code",
        queryset=Role.objects.all(),
        source="role",
    )
    permission_code = serializers.SlugRelatedField(
        slug_field="code",
        queryset=Permission.objects.all(),
        source="permission",
    )

    class Meta:
        model = RolePermission
        fields = ("id", "role_code", "permission_code", "assigned_at")
        read_only_fields = ("id", "assigned_at")
