from rest_framework.permissions import BasePermission


def has_permission(user, permission_code: str) -> bool:
    if not user or not user.is_authenticated:
        return False
    if user.is_superuser:
        return True
    return user.role_assignments.filter(
        role__permissions__code=permission_code,
    ).exists()


def has_role(user, role_name: str) -> bool:
    if not user or not user.is_authenticated:
        return False
    if user.is_superuser:
        return True
    return user.role_assignments.filter(
        role__code__iexact=role_name,
    ).exists() or user.role_assignments.filter(role__name__iexact=role_name).exists()


class HasPermission(BasePermission):
    message = "You do not have permission to perform this action."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True

        required = getattr(view, "required_permission", None)
        if required is None:
            action = getattr(view, "action", request.method.lower())
            permission_map = getattr(view, "permission_map", {})
            required = permission_map.get(action)

        if required is None:
            return False

        return has_permission(request.user, required)


class RBACPermission(HasPermission):
    def has_permission(self, request, view):
        permission_required = getattr(view, "permission_required", None)
        if permission_required is not None:
            view.required_permission = permission_required
        return super().has_permission(request, view)
