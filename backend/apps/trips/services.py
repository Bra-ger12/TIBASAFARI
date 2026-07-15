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
from django.db import transaction
from django.utils import timezone
from rest_framework import exceptions

from apps.drivers.models import DriverDocument
from apps.notifications.models import Notification
from apps.trips.models import Trip, TripAssignmentEvent, TripMessage

REQUIRED_DRIVER_DOC_TYPES = {
    DriverDocument.DocType.LICENSE,
    DriverDocument.DocType.INSURANCE,
    DriverDocument.DocType.VEHICLE_REGISTRATION,
}


def _push_trip_status(trip: "Trip"):
    """Broadcast a trip status change to the trip's own WS room, and to the
    dispatch-wide admin room so the live dashboard map can add/update/drop
    this trip without a page reload (non-blocking)."""
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"trip_{trip.id}",
            {"type": "trip.status", "trip_id": str(trip.id), "status": trip.status},
        )
        async_to_sync(channel_layer.group_send)(
            "dispatch",
            {
                "type": "dispatch.trip_update",
                "trip_id": str(trip.id),
                "status": trip.status,
                "driver_id": str(trip.driver_id) if trip.driver_id else None,
                "pickup_lat": float(trip.pickup_latitude) if trip.pickup_latitude is not None else None,
                "pickup_lng": float(trip.pickup_longitude) if trip.pickup_longitude is not None else None,
            },
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

    @transaction.atomic
    def assign_driver(self, trip, *, driver):
        trip = Trip.objects.select_for_update().get(pk=trip.pk)
        if trip.status not in {Trip.Status.REQUESTED, Trip.Status.CANCELLED}:
            raise exceptions.ValidationError("Only requested trips can be assigned")
        self._assert_driver_verified(driver)
        trip.driver = driver
        trip.status = Trip.Status.ASSIGNED
        trip.save(update_fields=["driver", "status", "updated_at"])
        _push_trip_status(trip)
        TripAssignmentEvent.objects.create(
            trip=trip, driver=driver, event_type=TripAssignmentEvent.EventType.ASSIGNED
        )

        profile = getattr(driver, "driver_profile", None)
        vehicle = getattr(profile, "vehicle", None) if profile else None
        vehicle_desc = (
            f"{vehicle.make} {vehicle.model} ({vehicle.registration_number})"
            if vehicle
            else None
        )
        message = f"Driver {driver.full_name} ({driver.phone}) has been assigned to your trip."
        if vehicle_desc:
            message += f" They'll arrive in a {vehicle_desc}."
        _notify(
            trip.patient,
            "Driver Assigned",
            message,
            {
                "trip_id": str(trip.id),
                "driver_id": str(driver.id),
                "driver_name": driver.full_name,
                "driver_phone": driver.phone,
                "vehicle": vehicle_desc,
            },
        )
        _notify(
            driver,
            "New Trip Assigned",
            f"You have been assigned a trip to {trip.destination_address}.",
            {"trip_id": str(trip.id)},
        )
        return trip

    @transaction.atomic
    def accept_trip(self, trip, *, driver):
        trip = Trip.objects.select_for_update().get(pk=trip.pk)
        self._assert_driver(trip, driver)
        if trip.status != Trip.Status.ASSIGNED:
            raise exceptions.ValidationError("Only assigned trips can be accepted")
        trip.status = Trip.Status.ACCEPTED
        trip.accepted_at = timezone.now()
        trip.save(update_fields=["status", "accepted_at", "updated_at"])
        _push_trip_status(trip)
        TripAssignmentEvent.objects.create(
            trip=trip, driver=driver, event_type=TripAssignmentEvent.EventType.ACCEPTED
        )
        _notify(
            trip.patient,
            "Driver On the Way",
            f"{driver.full_name} has accepted your trip and is heading to {trip.pickup_address}.",
            {"trip_id": str(trip.id)},
        )
        return trip

    @transaction.atomic
    def reject_trip(self, trip, *, driver):
        trip = Trip.objects.select_for_update().get(pk=trip.pk)
        self._assert_driver(trip, driver)
        if trip.status != Trip.Status.ASSIGNED:
            raise exceptions.ValidationError("Only assigned trips can be rejected")
        TripAssignmentEvent.objects.create(
            trip=trip, driver=driver, event_type=TripAssignmentEvent.EventType.REJECTED
        )
        trip.driver = None
        trip.status = Trip.Status.REQUESTED
        trip.save(update_fields=["driver", "status", "updated_at"])
        _push_trip_status(trip)
        _notify(
            trip.patient,
            "Driver Unavailable",
            "Your trip driver is unavailable. A new driver is being assigned.",
            {"trip_id": str(trip.id)},
        )
        return trip

    @transaction.atomic
    def start_trip(self, trip, *, driver):
        trip = Trip.objects.select_for_update().get(pk=trip.pk)
        self._assert_driver(trip, driver)
        if trip.status != Trip.Status.ACCEPTED:
            raise exceptions.ValidationError("Only accepted trips can be started")
        trip.status = Trip.Status.EN_ROUTE
        trip.started_at = timezone.now()
        trip.save(update_fields=["status", "started_at", "updated_at"])
        _push_trip_status(trip)
        _notify(
            trip.patient,
            "Trip Started",
            f"Your driver is en route to {trip.destination_address}. Track live in the app.",
            {"trip_id": str(trip.id)},
        )
        return trip

    @transaction.atomic
    def arrive_trip(self, trip, *, driver):
        trip = Trip.objects.select_for_update().get(pk=trip.pk)
        self._assert_driver(trip, driver)
        if trip.status != Trip.Status.EN_ROUTE:
            raise exceptions.ValidationError("Only en-route trips can be marked arrived")
        trip.status = Trip.Status.ARRIVED
        trip.arrived_at = timezone.now()
        trip.save(update_fields=["status", "arrived_at", "updated_at"])
        _push_trip_status(trip)
        _notify(
            trip.patient,
            "Arrived at Destination",
            f"Your driver has arrived at {trip.destination_address}.",
            {"trip_id": str(trip.id)},
        )
        return trip

    @transaction.atomic
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
        trip = Trip.objects.select_for_update().get(pk=trip.pk)
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

        # Final cost: Haversine distance from the trip's own stored
        # coordinates (reliable, no external API) + waiting time from
        # whatever the driver device reported as duration_minutes.
        if (
            trip.pickup_latitude is not None
            and trip.pickup_longitude is not None
            and trip.destination_latitude is not None
            and trip.destination_longitude is not None
        ):
            from apps.billing.services import (
                FareEstimator,
                fare_breakdown_to_json,
                service_type_for_trip,
            )

            breakdown = FareEstimator().estimate(
                pickup_lat=trip.pickup_latitude,
                pickup_lng=trip.pickup_longitude,
                dest_lat=trip.destination_latitude,
                dest_lng=trip.destination_longitude,
                service_type=service_type_for_trip(trip),
                waiting_minutes=trip.duration_minutes or 0,
                scheduled_at=trip.scheduled_at,
            )
            trip.final_fare = breakdown["total_fare"]
            trip.final_fare_breakdown = fare_breakdown_to_json(breakdown)
            update_fields += ["final_fare", "final_fare_breakdown"]

        trip.save(update_fields=update_fields)
        _push_trip_status(trip)

        # Auto-generate the invoice the moment a trip completes — without
        # this, a patient has no invoice to ever pay against (billing_screen
        # in patient_app only lists invoices that already exist).
        from apps.billing.services import InvoiceService

        try:
            InvoiceService().create_for_trip(trip)
        except Exception:
            pass  # billing hiccup shouldn't block the trip-completion response

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

    @transaction.atomic
    def cancel_trip(self, trip, *, user):
        trip = Trip.objects.select_for_update().get(pk=trip.pk)
        if trip.status == Trip.Status.COMPLETED:
            raise exceptions.ValidationError("Completed trips cannot be cancelled")
        trip.status = Trip.Status.CANCELLED
        trip.cancelled_at = timezone.now()
        trip.save(update_fields=["status", "cancelled_at", "updated_at"])
        _push_trip_status(trip)
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

    def _assert_driver_verified(self, driver):
        profile = getattr(driver, "driver_profile", None)
        if profile is None:
            raise exceptions.ValidationError(
                "Driver has no profile and cannot be dispatched"
            )
        verified_types = set(
            DriverDocument.objects.filter(
                driver=profile, status=DriverDocument.Status.VERIFIED
            ).values_list("doc_type", flat=True)
        )
        missing = REQUIRED_DRIVER_DOC_TYPES - verified_types
        if missing:
            raise exceptions.ValidationError(
                "Driver cannot be dispatched: missing verified documents "
                f"({', '.join(sorted(missing))})"
            )

    def _assert_participant(self, trip, user):
        from apps.rbac.permissions import has_permission

        if (
            trip.patient_id == user.id
            or trip.driver_id == user.id
            or has_permission(user, "manage_trips")
        ):
            return
        raise exceptions.PermissionDenied("You are not a participant on this trip")
