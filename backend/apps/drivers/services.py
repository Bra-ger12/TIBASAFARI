from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.utils import timezone
from rest_framework import exceptions

from apps.accounts.models import User
from apps.drivers.models import DriverProfile
from apps.notifications.models import Notification


class DriverService:
    def find_social_driver(self, *, email: str) -> User:
        """Used by Google sign-in: returns the existing driver account for
        this email. Unlike patients, driver accounts require a verified
        license and an approved profile, so sign-in never silently creates
        one — an email with no matching driver account is rejected."""
        email = email.strip().lower()
        user = User.objects.filter(
            email__iexact=email, driver_profile__isnull=False,
        ).first()
        if user is None:
            raise exceptions.AuthenticationFailed(
                "No driver account found for this email. "
                "Sign up with your license details first."
            )
        return user

    def create_profile(self, *, user, **data):
        return DriverProfile.objects.create(user=user, **data)

    def update_profile(self, profile, **data):
        for field, value in data.items():
            setattr(profile, field, value)
        profile.save()
        return profile

    def set_availability(self, profile, *, is_available: bool):
        profile.is_available = is_available
        profile.save(update_fields=["is_available", "updated_at"])
        return profile

    def update_location(self, profile, *, latitude, longitude):
        profile.current_latitude = latitude
        profile.current_longitude = longitude
        profile.last_location_at = timezone.now()
        profile.save(
            update_fields=[
                "current_latitude",
                "current_longitude",
                "last_location_at",
                "updated_at",
            ]
        )
        return profile

    def trigger_sos(
        self,
        profile,
        *,
        message: str = "",
        trip_id=None,
        latitude=None,
        longitude=None,
    ):
        """Broadcasts an emergency alert from this driver to all dispatch/
        admin users (anyone holding the manage_trips permission)."""
        alert_message = message.strip() or "Driver has triggered an SOS alert."
        title = "🚨 Driver SOS Alert"
        full_message = f"{profile.user.full_name}: {alert_message}"
        metadata = {
            "type": "sos",
            "driver_id": str(profile.user_id),
            "driver_name": profile.user.full_name,
            "driver_phone": profile.user.phone,
            "trip_id": str(trip_id) if trip_id else None,
            "latitude": str(latitude) if latitude is not None else None,
            "longitude": str(longitude) if longitude is not None else None,
        }

        dispatch_users = User.objects.filter(
            role_assignments__role__permissions__code="manage_trips"
        ).distinct()

        for user in dispatch_users:
            notif = Notification.objects.create(
                recipient=user,
                title=title,
                message=full_message,
                metadata=metadata,
            )
            try:
                channel_layer = get_channel_layer()
                async_to_sync(channel_layer.group_send)(
                    f"notifications_{user.id}",
                    {
                        "type": "notification.push",
                        "id": str(notif.id),
                        "title": notif.title,
                        "message": notif.message,
                        "metadata": notif.metadata,
                        "created_at": notif.created_at.isoformat(),
                    },
                )
            except Exception:
                pass  # WS unavailable during tests / cold start — don't crash HTTP

        return dispatch_users.count()

