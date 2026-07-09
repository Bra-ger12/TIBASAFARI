from rest_framework import exceptions


class EmailNotVerified(exceptions.PermissionDenied):
    """Raised by AuthService.login() when the account exists and the
    password is correct, but the patient hasn't entered their verification
    code yet. Distinct default_code from the generic PermissionDenied so
    clients can offer a "verify now" action instead of a plain error."""

    default_code = "email_not_verified"
    default_detail = "Please verify your email before logging in."
