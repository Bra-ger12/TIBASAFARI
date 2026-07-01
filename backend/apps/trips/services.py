"""
Trip service — handles the full trip state machine.

After each state transition:
  1. A Notification row is created for the relevant parties.
  2. A WebSocket broadcast is sent to the trip room group.
  3. An email is queued (fire-and-forget via thread to not block the request).
"""
import threading

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.core.mail import send_mail
from django.utils import timezone
from rest_framework import exceptions

from apps.notifications.models import Notification
from apps.trips.models import Trip, TripMessage


def _push_trip_status(trip_id: str, new_status: str):
    """Broadcast trip status change to the trip WS room (non-blocking)."""
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"trip_{trip_id}",
            {"type": "trip.status", "trip_id": str(trip_id), "status": new_status},
        )
    except Exception:
        pass  # WS unavailable during tests / cold start — don't crash HTTP


def _notify(recipient, title: str, message: str, metadata: dict = None):
    """Create a DB notification and push it via WebSocket."""
    notif = Notification.objects.create(
        recipient=recipient,
        title=title,
        message=message,
        metadata=metadata or {},
    )
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"notifications_{recipient.id}",
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
        pass


def _push_trip_chat(trip_id: str, message: "TripMessage"):
    """Broadcast a new chat message to the trip WS room (non-blocking)."""
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"trip_{trip_id}",
            {
                "type": "trip.chat",
                "id": str(message.id),
                "trip_id": str(trip_id),
                "sender_id": str(message.sender_id),
                "sender_name": message.sender.full_name,
                "body": message.body,
                "created_at": message.created_at.isoformat(),
            },
        )
    except Exception:
        pass  # WS unavailable during tests / cold start — don't crash HTTP


def _send_email_async(subject: str, body: str, to_email: str):
    def _send():
        try:
            send_mail(subject, body, None, [to_email], fail_silently=True)
        except Exception:
            pass

    threading.Thread(target=_send, daemon=True).start()


class TripService:
    driver_statuses = {
        Trip.Status.ASSIGNED,
        Trip.Status.ACCEPTED,
        Trip.Status.EN_ROUTE,
        Trip.Status.ARRIVED,
    }

    def create_trip(self, *, patient, **data):
        trip = Trip.objects.create(patient=patient, **data)
        _notify(
            patient,
            "Trip Requested",
            f"Your trip to {trip.destination_address} has been received and is pending dispatch.",
            {"trip_id": str(trip.id)},
        )
        _send_email_async(
            "Trip Request Received — Tiba Safari",
            f"Hi {patient.full_name},\n\nYour ride to {trip.destination_address} scheduled for "
            f"{trip.scheduled_at.strftime('%b %d, %Y %H:%M')} has been received.\n\nTiba Safari Team",
            patient.email,
        )
        return trip

    def assign_driver(self, trip, *, driver):
        if trip.status not in {Trip.Status.REQUESTED, Trip.Status.CANCELLED}:
            raise exceptions.ValidationError("Only requested trips can be assigned")
        trip.driver = driver
        trip.status = Trip.Status.ASSIGNED
        trip.save(update_fields=["driver", "status", "updated_at"])
        _push_trip_status(trip.id, trip.status)
        _notify(
            trip.patient,
            "Driver Assigned",
            f"Driver {driver.full_name} has been assigned to your trip.",
            {"trip_id": str(trip.id), "driver_id": str(driver.id)},
        )
        _notify(
            driver,
            "New Trip Assigned",
            f"You have been assigned a trip to {trip.destination_address}.",
            {"trip_id": str(trip.id)},
        )
        return trip

    def accept_trip(self, trip, *, driver):
        self._assert_driver(trip, driver)
        if trip.status != Trip.Status.ASSIGNED:
            raise exceptions.ValidationError("Only assigned trips can be accepted")
        trip.status = Trip.Status.ACCEPTED
        trip.accepted_at = timezone.now()
        trip.save(update_fields=["status", "accepted_at", "updated_at"])
        _push_trip_status(trip.id, trip.status)
        _notify(
            trip.patient,
            "Driver On the Way",
            f"{driver.full_name} has accepted your trip and is heading to {trip.pickup_address}.",
            {"trip_id": str(trip.id)},
        )
        return trip

    def reject_trip(self, trip, *, driver):
        self._assert_driver(trip, driver)
        if trip.status != Trip.Status.ASSIGNED:
            raise exceptions.ValidationError("Only assigned trips can be rejected")
        trip.driver = None
        trip.status = Trip.Status.REQUESTED
        trip.save(update_fields=["driver", "status", "updated_at"])
        _push_trip_status(trip.id, trip.status)
        _notify(
            trip.patient,
            "Driver Unavailable",
            "Your trip driver is unavailable. A new driver is being assigned.",
            {"trip_id": str(trip.id)},
        )
        return trip

    def start_trip(self, trip, *, driver):
        self._assert_driver(trip, driver)
        if trip.status != Trip.Status.ACCEPTED:
            raise exceptions.ValidationError("Only accepted trips can be started")
        trip.status = Trip.Status.EN_ROUTE
        trip.started_at = timezone.now()
        trip.save(update_fields=["status", "started_at", "updated_at"])
        _push_trip_status(trip.id, trip.status)
        _notify(
            trip.patient,
            "Trip Started",
            f"Your driver is en route to {trip.destination_address}. Track live in the app.",
            {"trip_id": str(trip.id)},
        )
        return trip

    def arrive_trip(self, trip, *, driver):
        self._assert_driver(trip, driver)
        if trip.status != Trip.Status.EN_ROUTE:
            raise exceptions.ValidationError("Only en-route trips can be marked arrived")
        trip.status = Trip.Status.ARRIVED
        trip.arrived_at = timezone.now()
        trip.save(update_fields=["status", "arrived_at", "updated_at"])
        _push_trip_status(trip.id, trip.status)
        _notify(
            trip.patient,
            "Arrived at Destination",
            f"Your driver has arrived at {trip.destination_address}.",
            {"trip_id": str(trip.id)},
        )
        return trip

    def complete_trip(
        self,
        trip,
        *,
        driver,
        distance_km=None,
        duration_minutes=None,
        signature=None,
        proof_photo=None,
    ):
        self._assert_driver(trip, driver)
        if trip.status not in {Trip.Status.EN_ROUTE, Trip.Status.ARRIVED}:
            raise exceptions.ValidationError("Only active trips can be completed")
        trip.status = Trip.Status.COMPLETED
        trip.completed_at = timezone.now()
        update_fields = ["status", "completed_at", "updated_at"]
        if distance_km is not None:
            trip.distance_km = distance_km
            update_fields.append("distance_km")
        if duration_minutes is not None:
            trip.duration_minutes = duration_minutes
            update_fields.append("duration_minutes")
        if signature is not None:
            trip.signature = signature
            update_fields.append("signature")
        if proof_photo is not None:
            trip.proof_photo = proof_photo
            update_fields.append("proof_photo")
        trip.save(update_fields=update_fields)
        _push_trip_status(trip.id, trip.status)
        _notify(
            trip.patient,
            "Trip Completed",
            "Your trip has been completed. Thank you for using Tiba Safari!",
            {"trip_id": str(trip.id)},
        )
        _send_email_async(
            "Trip Completed — Tiba Safari",
            f"Hi {trip.patient.full_name},\n\nYour trip to {trip.destination_address} has been completed.\n\nTiba Safari Team",
            trip.patient.email,
        )
        return trip

    def cancel_trip(self, trip, *, user):
        if trip.status == Trip.Status.COMPLETED:
            raise exceptions.ValidationError("Completed trips cannot be cancelled")
        trip.status = Trip.Status.CANCELLED
        trip.cancelled_at = timezone.now()
        trip.save(update_fields=["status", "cancelled_at", "updated_at"])
        _push_trip_status(trip.id, trip.status)
        if trip.driver_id:
            _notify(
                trip.driver,
                "Trip Cancelled",
                f"Trip to {trip.destination_address} has been cancelled.",
                {"trip_id": str(trip.id)},
            )
        _notify(
            trip.patient,
            "Trip Cancelled",
            f"Your trip to {trip.destination_address} has been cancelled.",
            {"trip_id": str(trip.id)},
        )
        return trip

    def send_trip_message(self, trip, *, sender, body):
        self._assert_participant(trip, sender)
        message = TripMessage.objects.create(trip=trip, sender=sender, body=body)
        _push_trip_chat(trip.id, message)

        from apps.rbac.permissions import has_permission

        if has_permission(sender, "manage_trips"):
            # Dispatch replying — notify whichever party is not already dispatch.
            for recipient in (trip.patient, trip.driver):
                if recipient and recipient.id != sender.id:
                    _notify(
                        recipient,
                        "New message from dispatch",
                        f"{sender.full_name}: {body[:80]}",
                        {"trip_id": str(trip.id), "type": "chat"},
                    )
        else:
            recipient = trip.driver if sender.id == trip.patient_id else trip.patient
            if recipient:
                _notify(
                    recipient,
                    f"New message from {sender.full_name}",
                    body[:80],
                    {"trip_id": str(trip.id), "type": "chat"},
                )
        return message

    def _assert_driver(self, trip, driver):
        if trip.driver_id != driver.id:
            raise exceptions.PermissionDenied("This trip is not assigned to this driver")

    def _assert_participant(self, trip, user):
        from apps.rbac.permissions import has_permission

        if (
            trip.patient_id == user.id
            or trip.driver_id == user.id
            or has_permission(user, "manage_trips")
        ):
            return
        raise exceptions.PermissionDenied("You are not a participant on this trip")
