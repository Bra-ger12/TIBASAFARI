from rest_framework import serializers

from apps.billing.models import Invoice, Payment, SavedPaymentMethod


class SavedPaymentMethodSerializer(serializers.ModelSerializer):
    class Meta:
        model = SavedPaymentMethod
        fields = ("id", "method_type", "label", "is_default", "created_at")
        read_only_fields = ("id", "label", "is_default", "created_at")


class AddPaymentMethodSerializer(serializers.Serializer):
    """Client sends the raw identifier (phone number / card number); only a
    masked label is ever persisted — the full value is never stored."""

    method_type = serializers.ChoiceField(choices=SavedPaymentMethod.MethodType.choices)
    identifier = serializers.CharField(max_length=40, min_length=4)

    def validate_identifier(self, value):
        digits = "".join(ch for ch in value if ch.isdigit())
        if len(digits) < 4:
            raise serializers.ValidationError(
                "Enter a valid phone number or card number (at least 4 digits)"
            )
        return digits

    def to_label(self) -> str:
        last4 = self.validated_data["identifier"][-4:]
        prefix = (
            "M-Pesa"
            if self.validated_data["method_type"] == SavedPaymentMethod.MethodType.MOBILE_MONEY
            else "Card"
        )
        return f"{prefix} •••• {last4}"


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = (
            "id",
            "amount",
            "method",
            "status",
            "reference",
            "notes",
            "recorded_by",
            "processed_at",
            "created_at",
        )
        read_only_fields = ("id", "status", "recorded_by", "processed_at", "created_at")


class InvoiceSerializer(serializers.ModelSerializer):
    payments = PaymentSerializer(many=True, read_only=True)
    patient_email = serializers.EmailField(source="patient.email", read_only=True)
    trip_status = serializers.CharField(source="trip.status", read_only=True)

    class Meta:
        model = Invoice
        fields = (
            "id",
            "invoice_number",
            "trip",
            "trip_status",
            "patient",
            "patient_email",
            "base_fare",
            "distance_km",
            "distance_charge",
            "duration_minutes",
            "time_charge",
            "wheelchair_surcharge",
            "discount",
            "subtotal",
            "tax_rate",
            "tax_amount",
            "total_amount",
            "amount_paid",
            "amount_due",
            "status",
            "notes",
            "due_date",
            "issued_at",
            "paid_at",
            "created_at",
            "updated_at",
            "payments",
        )
        read_only_fields = (
            "id",
            "invoice_number",
            "patient_email",
            "trip_status",
            "base_fare",
            "distance_charge",
            "time_charge",
            "wheelchair_surcharge",
            "subtotal",
            "tax_amount",
            "total_amount",
            "amount_paid",
            "amount_due",
            "issued_at",
            "paid_at",
            "created_at",
            "updated_at",
            "payments",
        )


class PaymentQueueSerializer(serializers.ModelSerializer):
    """Payment + enough invoice/patient context to render a staff verification queue."""

    invoice_number = serializers.CharField(source="invoice.invoice_number", read_only=True)
    invoice_total = serializers.DecimalField(
        source="invoice.total_amount", max_digits=10, decimal_places=2, read_only=True
    )
    invoice_amount_due = serializers.DecimalField(
        source="invoice.amount_due", max_digits=10, decimal_places=2, read_only=True
    )
    patient_name = serializers.CharField(source="invoice.patient.full_name", read_only=True)
    patient_email = serializers.EmailField(source="invoice.patient.email", read_only=True)

    class Meta:
        model = Payment
        fields = (
            "id",
            "invoice",
            "invoice_number",
            "invoice_total",
            "invoice_amount_due",
            "patient_name",
            "patient_email",
            "amount",
            "method",
            "status",
            "reference",
            "notes",
            "recorded_by",
            "processed_at",
            "created_at",
        )
        read_only_fields = fields


class RejectPaymentSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=500, default="", allow_blank=True)


class RecordPaymentSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    method = serializers.ChoiceField(choices=Payment.Method.choices)
    reference = serializers.CharField(max_length=120, default="", allow_blank=True)
    notes = serializers.CharField(default="", allow_blank=True)

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError("Amount must be greater than zero")
        return value


class SubmitPaymentSerializer(serializers.Serializer):
    """Patient self-reports a payment made outside the app (e.g. an M-Pesa
    transfer). Creates a PENDING Payment for staff to verify — unlike
    RecordPaymentSerializer/record_payment, this does NOT update the
    invoice balance; only staff confirming via record_payment does that."""

    PATIENT_METHODS = (
        Payment.Method.CASH,
        Payment.Method.MOBILE_MONEY,
        Payment.Method.BANK_TRANSFER,
        Payment.Method.CARD,
    )

    amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    method = serializers.ChoiceField(choices=[(m, m.label) for m in PATIENT_METHODS])
    reference = serializers.CharField(max_length=120, required=False, allow_blank=True)
    notes = serializers.CharField(default="", allow_blank=True)

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError("Amount must be greater than zero")
        return value

    def validate(self, attrs):
        # Cash has no confirmation code to check, unlike the other methods —
        # only require a reference for non-cash payments.
        if attrs.get("method") != Payment.Method.CASH and not attrs.get("reference", "").strip():
            raise serializers.ValidationError(
                {"reference": "A payment reference (e.g. M-Pesa confirmation code) is required"}
            )
        attrs["reference"] = attrs.get("reference", "").strip()
        return attrs


class GenerateInvoiceSerializer(serializers.Serializer):
    trip_id = serializers.UUIDField()
    distance_km = serializers.FloatField(min_value=0.0, default=0.0)
    duration_minutes = serializers.IntegerField(min_value=0, default=0)
    discount = serializers.DecimalField(max_digits=10, decimal_places=2, default="0.00")
    tax_rate = serializers.DecimalField(max_digits=5, decimal_places=4, default="0.0000")
