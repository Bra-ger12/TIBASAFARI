import uuid

from django.conf import settings
from django.db import models


class Permission(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    code = models.CharField(max_length=120, unique=True)
    name = models.CharField(max_length=120)
    description = models.TextField(blank=True)

    class Meta:
        ordering = ("code",)

    def __str__(self) -> str:
        return self.code


class Role(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    code = models.CharField(max_length=80, unique=True)
    name = models.CharField(max_length=120, unique=True)
    description = models.TextField(blank=True)
    permissions = models.ManyToManyField(
        Permission,
        related_name="roles",
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("code",)

    def __str__(self) -> str:
        return self.code


class UserRole(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="role_assignments",
        on_delete=models.CASCADE,
    )
    role = models.ForeignKey(
        Role,
        related_name="user_assignments",
        on_delete=models.CASCADE,
    )
    assigned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("user", "role"),
                name="unique_user_role_assignment",
            )
        ]

    def __str__(self) -> str:
        return f"{self.user_id}:{self.role.code}"


class RolePermission(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    role = models.ForeignKey(
        Role,
        related_name="permission_assignments",
        on_delete=models.CASCADE,
    )
    permission = models.ForeignKey(
        Permission,
        related_name="role_assignments",
        on_delete=models.CASCADE,
    )
    assigned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("role", "permission"),
                name="unique_role_permission_assignment",
            )
        ]

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self.role.permissions.add(self.permission)

    def delete(self, *args, **kwargs):
        role = self.role
        permission = self.permission
        deleted = super().delete(*args, **kwargs)
        role.permissions.remove(permission)
        return deleted

    def __str__(self) -> str:
        return f"{self.role.code}:{self.permission.code}"
