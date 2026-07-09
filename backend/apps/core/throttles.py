from rest_framework.throttling import ScopedRateThrottle


class EmailOTPRequestThrottle(ScopedRateThrottle):
    """Applied to signup / resend-verification / password-reset-request —
    endpoints that trigger an outbound email — to prevent abuse. Rate comes
    from DEFAULT_THROTTLE_RATES["email_otp"] (see EMAIL_OTP_THROTTLE_RATE)."""

    scope = "email_otp"
