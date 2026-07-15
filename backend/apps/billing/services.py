"""
Fare calculation and invoice generation services.

Fare formula:
  base_fare
  + distance_km * FARE_PER_KM
  + duration_minutes * FARE_PER_MINUTE
  + wheelchair_surcharge (if applicable)
  - discount
  = subtotal → apply tax → total_amount
  minimum: FARE_MINIMUM
"""
from decimal import ROUND_HALF_UP, Decimal

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.conf import settings
from django.utils import timezone
from rest_framework import exceptions

from apps.billing.models import Invoice, Payment, PricingConfig
from apps.core.geo import haversine_distance_km
from apps.trips.models import Trip


def _d(value) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _notify(recipient, title: str, message: str, metadata: dict = None):
    """Create a DB notification and push it via WebSocket (best-effort)."""
    from apps.notifications.models import Notification

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


class FareCalculator:
    def __init__(self):
        self.base_rate = _d(settings.FARE_BASE_RATE)
        self.per_km = _d(settings.FARE_PER_KM)
        self.per_minute = _d(settings.FARE_PER_MINUTE)
        self.minimum = _d(settings.FARE_MINIMUM)
        self.wheelchair_surcharge = _d(settings.FARE_WHEELCHAIR_SURCHARGE)

    def calculate(
        self,
        distance_km: float,
        duration_minutes: int,
        *,
        wheelchair: bool = False,
        discount: Decimal = Decimal("0.00"),
        tax_rate: Decimal = Decimal("0.00"),
    ) -> dict:
        distance_km = _d(distance_km)
        duration_minutes = int(duration_minutes)

        base_fare = self.base_rate
        distance_charge = (distance_km * self.per_km).quantize(
            Decimal("0.01"), rounding=ROUND_HALF_UP
        )
        time_charge = (_d(duration_minutes) * self.per_minute).quantize(
            Decimal("0.01"), rounding=ROUND_HALF_UP
        )
        w_surcharge = self.wheelchair_surcharge if wheelchair else Decimal("0.00")

        subtotal = base_fare + distance_charge + time_charge + w_surcharge - _d(discount)
        subtotal = max(subtotal, self.minimum)

        tax_rate = _d(tax_rate)
        tax_amount = (subtotal * tax_rate).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        total = subtotal + tax_amount

        return {
            "base_fare": base_fare,
            "distance_km": distance_km,
            "distance_charge": distance_charge,
            "duration_minutes": duration_minutes,
            "time_charge": time_charge,
            "wheelchair_surcharge": w_surcharge,
            "discount": _d(discount),
            "subtotal": subtotal,
            "tax_rate": tax_rate,
            "tax_amount": tax_amount,
            "total_amount": total,
            "amount_due": total,
            "amount_paid": Decimal("0.00"),
        }


# Local hour (Africa/Dar_es_Salaam, per settings.TIME_ZONE) windows during
# which the peak-hour surcharge applies: 7-9am, 12-1pm, 5-7pm. Each tuple is
# [start, end) — end-exclusive.
PEAK_HOUR_WINDOWS = [(7, 9), (12, 13), (17, 19)]


def _is_peak_hour(dt) -> bool:
    local_hour = timezone.localtime(dt).hour
    return any(start <= local_hour < end for start, end in PEAK_HOUR_WINDOWS)


def _is_urban_zone(lat, lng, config: PricingConfig) -> bool:
    if lat is None or lng is None:
        return False
    distance = haversine_distance_km(
        lat, lng, config.urban_zone_center_lat, config.urban_zone_center_lng
    )
    return distance <= float(config.urban_zone_radius_km)


def fare_breakdown_to_json(breakdown: dict) -> dict:
    """FareEstimator.estimate() returns Decimal values (correct for the DRF
    response, which serializes them to strings automatically) — but a raw
    dict with Decimal objects isn't JSON-serializable, so it can't be
    assigned directly to a JSONField. Call this first when persisting a
    breakdown (see TripService.complete_trip)."""
    return {k: (str(v) if isinstance(v, Decimal) else v) for k, v in breakdown.items()}


def service_type_for_trip(trip: Trip) -> str:
    """Maps a Trip's mobility/medical fields onto a PricingConfig service
    type, for the final (post-completion) fare calculation."""
    if trip.needs_wheelchair_vehicle():
        return PricingConfig.ServiceType.WHEELCHAIR
    if (
        trip.oxygen_required
        or trip.medical_escort_required
        or trip.iv_drip_required
        or trip.bariatric
        or trip.mobility_aid == Trip.MobilityAid.STRETCHER
    ):
        return PricingConfig.ServiceType.MEDICAL_EQUIPMENT
    return PricingConfig.ServiceType.BASIC


class FareEstimator:
    """Hybrid fare calculator: base fare + Haversine distance + waiting
    time + service-type multiplier + peak-hour/urban-zone surcharges.

    No external distance/geocoding API — distance comes from the Haversine
    formula applied to raw lat/lng points. Used both for the pre-booking
    /trips/estimate-fare/ quote and the post-completion final cost
    (TripService.complete_trip).
    """

    def __init__(self, config: PricingConfig = None):
        self.config = config or PricingConfig.get_active()

    def estimate(
        self,
        *,
        pickup_lat,
        pickup_lng,
        dest_lat,
        dest_lng,
        service_type: str = PricingConfig.ServiceType.BASIC,
        waiting_minutes: int = 0,
        scheduled_at=None,
    ) -> dict:
        scheduled_at = scheduled_at or timezone.now()
        cfg = self.config

        # ── Distance (Haversine — no external API) ─────────────────────
        distance_km = _d(haversine_distance_km(pickup_lat, pickup_lng, dest_lat, dest_lng))
        waiting_minutes = max(0, int(waiting_minutes))

        # ── Base + distance + waiting-time components ──────────────────
        base_fare = _d(cfg.base_fare)
        distance_charge = _d(distance_km * cfg.per_km_rate)
        waiting_charge = _d(_d(waiting_minutes) * cfg.per_minute_wait_rate)
        subtotal_before_multiplier = base_fare + distance_charge + waiting_charge

        # ── Service-type multiplier (basic / wheelchair / medical equip.) ─
        multiplier = cfg.multiplier_for(service_type)
        subtotal_after_multiplier = _d(subtotal_before_multiplier * multiplier)

        # ── Peak-hour surcharge: 7-9am, 12-1pm, 5-7pm local time (+20% default) ─
        is_peak = _is_peak_hour(scheduled_at)
        peak_surcharge_amount = (
            _d(subtotal_after_multiplier * cfg.peak_hour_surcharge_pct)
            if is_peak
            else Decimal("0.00")
        )

        # ── Urban zone markup: pickup within radius of city center (+10% default) ─
        is_urban = _is_urban_zone(pickup_lat, pickup_lng, cfg)
        zone_surcharge_amount = (
            _d(subtotal_after_multiplier * cfg.urban_zone_surcharge_pct)
            if is_urban
            else Decimal("0.00")
        )

        total_fare = subtotal_after_multiplier + peak_surcharge_amount + zone_surcharge_amount
        total_fare = max(total_fare, _d(cfg.minimum_fare))

        return {
            "distance_km": float(distance_km),
            "base_fare": base_fare,
            "distance_charge": distance_charge,
            "waiting_minutes": waiting_minutes,
            "waiting_charge": waiting_charge,
            "service_type": str(service_type),
            "service_multiplier": multiplier,
            "subtotal_after_multiplier": subtotal_after_multiplier,
            "is_peak_hour": is_peak,
            "peak_surcharge_amount": peak_surcharge_amount,
            "is_urban_zone": is_urban,
            "zone_surcharge_amount": zone_surcharge_amount,
            "minimum_fare": _d(cfg.minimum_fare),
            "total_fare": total_fare,
        }


class InvoiceService:
    calculator = FareCalculator()

    def create_for_trip(
        self,
        trip: Trip,
        distance_km: float = None,
        duration_minutes: int = None,
        discount: Decimal = Decimal("0.00"),
        tax_rate: Decimal = Decimal("0.00"),
    ) -> Invoice:
        if hasattr(trip, "invoice"):
            return trip.invoice

        # Automatic path (TripService.complete_trip calls this with no
        # overrides): the trip already has an authoritative final_fare from
        # FareEstimator (set at completion) — use it directly rather than
        # recomputing with the simpler base+distance+time formula below,
        # so the invoice total always matches the "final fare" shown
        # everywhere else in the apps.
        no_overrides = (
            distance_km is None
            and duration_minutes is None
            and discount == Decimal("0.00")
            and tax_rate == Decimal("0.00")
        )
        if trip.final_fare is not None and no_overrides:
            breakdown = trip.final_fare_breakdown or {}
            invoice = Invoice.objects.create(
                trip=trip,
                patient=trip.patient,
                status=Invoice.Status.ISSUED,
                issued_at=timezone.now(),
                base_fare=_d(breakdown.get("base_fare", 0)),
                distance_km=_d(breakdown.get("distance_km") or trip.distance_km or 0),
                distance_charge=_d(breakdown.get("distance_charge", 0)),
                duration_minutes=trip.duration_minutes or 0,
                time_charge=_d(breakdown.get("waiting_charge", 0)),
                wheelchair_surcharge=Decimal("0.00"),
                discount=Decimal("0.00"),
                subtotal=_d(breakdown.get("subtotal_after_multiplier", trip.final_fare)),
                tax_rate=Decimal("0.00"),
                tax_amount=Decimal("0.00"),
                total_amount=_d(trip.final_fare),
                amount_due=_d(trip.final_fare),
            )
            return invoice

        # Manual/edge-case path (staff explicitly provided distance/duration/
        # discount/tax via the admin "Generate Invoice" action, or the trip
        # has no final_fare yet — e.g. missing coordinates at completion).
        wheelchair = "wheelchair" in (trip.special_requirements or "").lower()
        fare = self.calculator.calculate(
            distance_km or 0.0,
            duration_minutes or 0,
            wheelchair=wheelchair,
            discount=discount,
            tax_rate=tax_rate,
        )

        invoice = Invoice.objects.create(
            trip=trip,
            patient=trip.patient,
            status=Invoice.Status.ISSUED,
            issued_at=timezone.now(),
            **fare,
        )
        return invoice

    def submit_payment(
        self,
        invoice: Invoice,
        amount: Decimal,
        method: str,
        *,
        reference: str = "",
        notes: str = "",
    ) -> Payment:
        """Patient self-reports a payment made outside the app. Creates a
        PENDING Payment only — the invoice balance is untouched until staff
        verify and confirm it via record_payment()."""
        return Payment.objects.create(
            invoice=invoice,
            amount=amount,
            method=method,
            status=Payment.Status.PENDING,
            reference=reference,
            notes=notes,
        )

    def record_payment(
        self,
        invoice: Invoice,
        amount: Decimal,
        method: str,
        *,
        reference: str = "",
        recorded_by=None,
    ) -> Payment:
        payment = Payment.objects.create(
            invoice=invoice,
            amount=amount,
            method=method,
            status=Payment.Status.COMPLETED,
            reference=reference,
            recorded_by=recorded_by,
            processed_at=timezone.now(),
        )
        invoice.amount_paid += amount
        invoice.amount_due = max(Decimal("0.00"), invoice.total_amount - invoice.amount_paid)
        if invoice.amount_due == Decimal("0.00"):
            invoice.status = Invoice.Status.PAID
            invoice.paid_at = timezone.now()
        else:
            invoice.status = Invoice.Status.PARTIALLY_PAID
        invoice.save(update_fields=["amount_paid", "amount_due", "status", "paid_at", "updated_at"])
        return payment

    def verify_payment(self, payment: Payment, *, verified_by) -> Payment:
        """Staff confirms a patient's self-reported (submit_payment) payment —
        marks that same Payment row COMPLETED and applies it to the invoice
        balance, instead of record_payment's behaviour of creating a new one."""
        if payment.status != Payment.Status.PENDING:
            raise exceptions.ValidationError("Only pending payments can be verified")

        payment.status = Payment.Status.COMPLETED
        payment.recorded_by = verified_by
        payment.processed_at = timezone.now()
        payment.save(update_fields=["status", "recorded_by", "processed_at"])

        invoice = payment.invoice
        invoice.amount_paid += payment.amount
        invoice.amount_due = max(Decimal("0.00"), invoice.total_amount - invoice.amount_paid)
        if invoice.amount_due == Decimal("0.00"):
            invoice.status = Invoice.Status.PAID
            invoice.paid_at = timezone.now()
        else:
            invoice.status = Invoice.Status.PARTIALLY_PAID
        invoice.save(update_fields=["amount_paid", "amount_due", "status", "paid_at", "updated_at"])

        _notify(
            invoice.patient,
            "Payment Verified",
            f"Your payment of {payment.amount} for invoice {invoice.invoice_number} has been verified.",
            {"invoice_id": str(invoice.id), "payment_id": str(payment.id)},
        )
        return payment

    def reject_payment(self, payment: Payment, *, reason: str = "") -> Payment:
        if payment.status != Payment.Status.PENDING:
            raise exceptions.ValidationError("Only pending payments can be rejected")

        payment.status = Payment.Status.FAILED
        if reason:
            payment.notes = f"{payment.notes}\n[Rejected: {reason}]".strip()
        payment.save(update_fields=["status", "notes"])

        invoice = payment.invoice
        _notify(
            invoice.patient,
            "Payment Could Not Be Verified",
            (
                f"Your submitted payment of {payment.amount} for invoice "
                f"{invoice.invoice_number} could not be verified"
                + (f": {reason}" if reason else ".")
            ),
            {"invoice_id": str(invoice.id), "payment_id": str(payment.id)},
        )
        return payment
