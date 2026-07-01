from django.contrib.auth import authenticate
from rest_framework import exceptions
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.repositories import UserRepository


class AuthService:
    def login(self, *, email: str, password: str):
        user = authenticate(email=email, password=password)
        if user is None:
            raise exceptions.AuthenticationFailed("Invalid email or password")
        if not user.is_approved:
            raise exceptions.PermissionDenied("Account is not active")

        refresh = RefreshToken.for_user(user)
        refresh["roles"] = list(
            user.role_assignments.values_list("role__code", flat=True)
        )
        return {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "user": user,
        }


class UserService:
    repository = UserRepository()

    def register_admin(self, *, email, password, full_name, phone_number=""):
        existing = self.repository.get_by_email(email)
        if existing:
            raise exceptions.ValidationError({"email": "Email is already registered"})
        return self.repository.create(
            email=email,
            password=password,
            full_name=full_name,
            phone_number=phone_number,
            is_active=False,
        )
