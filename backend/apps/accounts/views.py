from drf_spectacular.utils import extend_schema
from rest_framework import exceptions, status, viewsets
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import EmailOTP, User
from apps.accounts.serializers import (
    AdminSignupSerializer,
    ChangePasswordSerializer,
    LoginSerializer,
    LogoutSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    TokenResponseSerializer,
    UserSerializer,
)
from apps.accounts.services import AuthService, EmailOTPService, UserService
from apps.core.responses import success_response
from apps.core.throttles import EmailOTPRequestThrottle
from apps.rbac.permissions import HasPermission


def _blacklist_all_tokens(user):
    """Ends every other session after a password change/reset — without
    this, a stolen/leaked password's existing refresh tokens kept working
    indefinitely even after the legitimate owner changed it. Access tokens
    already in use still work until they naturally expire (see
    ACCESS_TOKEN_LIFETIME_MINUTES); only refresh tokens are blacklisted."""
    for token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=token)


class LoginView(APIView):
    permission_classes = [AllowAny]
    serializer_class = LoginSerializer
    auth_service = AuthService()

    @extend_schema(
        request=LoginSerializer,
        responses={200: TokenResponseSerializer},
    )
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        session = self.auth_service.login(**serializer.validated_data)
        data = {
            "access": session["access"],
            "refresh": session["refresh"],
            "user": UserSerializer(session["user"]).data,
        }
        return success_response(data, "Login successful")


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = LogoutSerializer

    @extend_schema(request=LogoutSerializer)
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        RefreshToken(serializer.validated_data["refresh"]).blacklist()
        return success_response(message="Logout successful")


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ChangePasswordSerializer

    @extend_schema(request=ChangePasswordSerializer)
    def post(self, request):
        serializer = self.serializer_class(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data["new_password"])
        request.user.save(update_fields=["password"])
        _blacklist_all_tokens(request.user)
        return success_response(message="Password changed successfully")


class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]
    serializer_class = PasswordResetRequestSerializer
    throttle_classes = [EmailOTPRequestThrottle]
    throttle_scope = "email_otp"
    otp_service = EmailOTPService()

    @extend_schema(request=PasswordResetRequestSerializer)
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = User.objects.filter(email__iexact=serializer.validated_data["email"]).first()
        if user is not None:
            code = self.otp_service.generate(user, purpose=EmailOTP.Purpose.PASSWORD_RESET)
            self.otp_service.send_password_reset_email(user, code)
        # Response is intentionally identical either way to avoid leaking
        # whether the email is registered.
        return success_response(message="Password reset instructions sent if the email exists")


class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]
    serializer_class = PasswordResetConfirmSerializer
    otp_service = EmailOTPService()

    @extend_schema(request=PasswordResetConfirmSerializer)
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            user = User.objects.get(email__iexact=data["email"])
        except User.DoesNotExist as exc:
            raise exceptions.ValidationError("Invalid or expired code") from exc
        if not self.otp_service.verify(
            user, purpose=EmailOTP.Purpose.PASSWORD_RESET, code=data["code"]
        ):
            raise exceptions.ValidationError("Invalid or expired code")
        user.set_password(data["new_password"])
        user.save(update_fields=["password"])
        _blacklist_all_tokens(user)
        return success_response(message="Password reset successfully")


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return success_response(UserSerializer(request.user).data)

    @extend_schema(request=UserSerializer, responses={200: UserSerializer})
    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return success_response(serializer.data, "Profile updated")


class AdminSignupView(APIView):
    permission_classes = [AllowAny]
    serializer_class = AdminSignupSerializer
    user_service = UserService()

    @extend_schema(request=AdminSignupSerializer, responses={201: UserSerializer})
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        validated = dict(serializer.validated_data)
        validated.pop("confirm_password")
        user = self.user_service.register_admin(**validated)
        return success_response(
            UserSerializer(user).data,
            "Signup request submitted",
            status=status.HTTP_201_CREATED,
        )


class UserViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = UserSerializer
    queryset = User.objects.prefetch_related("role_assignments__role").all()
    permission_classes = [HasPermission]
    required_permission = "accounts.view_user"
