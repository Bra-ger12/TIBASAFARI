import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

String formatCurrency(double amount, {String currency = 'TZS'}) {
  final formatted = NumberFormat.decimalPatternDigits(
    locale: 'en_US',
    decimalDigits: 0,
  ).format(amount.round());
  return '$currency $formatted';
}

String formatCompactCurrency(double amount, {String currency = 'TZS'}) {
  if (amount >= 1000000) {
    return '$currency ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return '$currency ${(amount / 1000).toStringAsFixed(1)}K';
  }
  return '$currency ${amount.round()}';
}

String formatNumber(num n) => NumberFormat.decimalPatternDigits(
      locale: 'en_US',
      decimalDigits: 0,
    ).format(n);

String formatDate(String? iso, {bool withTime = false}) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    if (withTime) return DateFormat('d MMM yyyy, HH:mm').format(d);
    return DateFormat('d MMM yyyy').format(d);
  } catch (_) {
    return '—';
  }
}

String formatRelative(String iso) {
  final d = DateTime.parse(iso).toLocal();
  final diff = DateTime.now().difference(d);
  final abs = diff.abs();
  if (abs.inMinutes < 1) return 'just now';
  if (abs.inHours < 1) {
    final v = abs.inMinutes;
    return diff.isNegative ? 'in ${v}m' : '${v}m ago';
  }
  if (abs.inDays < 1) {
    final v = abs.inHours;
    return diff.isNegative ? 'in ${v}h' : '${v}h ago';
  }
  final v = abs.inDays;
  return diff.isNegative ? 'in ${v}d' : '${v}d ago';
}

String initials(String name) {
  final parts = name.split(' ').where((s) => s.isNotEmpty).take(2).toList();
  return parts.map((p) => p[0].toUpperCase()).join();
}

Color avatarColor(String? color) {
  switch (color) {
    case 'emerald':
      return const Color(0xFF059669);
    case 'rose':
      return const Color(0xFFE11D48);
    case 'amber':
      return const Color(0xFFD97706);
    case 'violet':
      return const Color(0xFF7C3AED);
    case 'cyan':
      return const Color(0xFF0891B2);
    case 'orange':
      return const Color(0xFFEA580C);
    case 'blue':
      return const Color(0xFF0284C7);
    case 'green':
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFF475569);
  }
}

// Status metadata helpers
class StatusMeta {
  final String label;
  final StatusTone tone;
  const StatusMeta(this.label, this.tone);
}

StatusMeta bookingStatus(String s) {
  switch (s) {
    case 'pending':
      return const StatusMeta('Pending', StatusTone.amber);
    case 'approved':
      return const StatusMeta('Approved', StatusTone.blue);
    case 'assigned':
      return const StatusMeta('Assigned', StatusTone.blue);
    case 'ongoing':
      return const StatusMeta('Ongoing', StatusTone.blue);
    case 'completed':
      return const StatusMeta('Completed', StatusTone.green);
    case 'cancelled':
      return const StatusMeta('Cancelled', StatusTone.red);
    default:
      return StatusMeta(s, StatusTone.slate);
  }
}

StatusMeta tripStatus(String s) {
  switch (s) {
    case 'active':
      return const StatusMeta('Active', StatusTone.blue);
    case 'completed':
      return const StatusMeta('Completed', StatusTone.green);
    case 'cancelled':
      return const StatusMeta('Cancelled', StatusTone.red);
    default:
      return StatusMeta(s, StatusTone.slate);
  }
}

StatusMeta paymentStatus(String s) {
  switch (s.toUpperCase()) {
    case 'PENDING':
      return const StatusMeta('Pending', StatusTone.amber);
    case 'COMPLETED':
      return const StatusMeta('Completed', StatusTone.green);
    case 'FAILED':
      return const StatusMeta('Failed', StatusTone.red);
    case 'REFUNDED':
      return const StatusMeta('Refunded', StatusTone.slate);
    default:
      return StatusMeta(s, StatusTone.slate);
  }
}

StatusMeta invoiceStatus(String s) {
  switch (s) {
    case 'unpaid':
      return const StatusMeta('Unpaid', StatusTone.amber);
    case 'partially_paid':
      return const StatusMeta('Partially Paid', StatusTone.blue);
    case 'paid':
      return const StatusMeta('Paid', StatusTone.green);
    case 'overdue':
      return const StatusMeta('Overdue', StatusTone.red);
    default:
      return StatusMeta(s, StatusTone.slate);
  }
}

StatusMeta driverStatus(String s) {
  switch (s) {
    case 'online':
      return const StatusMeta('Online', StatusTone.green);
    case 'offline':
      return const StatusMeta('Offline', StatusTone.slate);
    case 'on_trip':
      return const StatusMeta('On Trip', StatusTone.blue);
    default:
      return StatusMeta(s, StatusTone.slate);
  }
}

StatusMeta vehicleStatus(String s) {
  switch (s) {
    case 'available':
      return const StatusMeta('Available', StatusTone.green);
    case 'on_trip':
      return const StatusMeta('On Trip', StatusTone.blue);
    case 'maintenance':
      return const StatusMeta('Maintenance', StatusTone.amber);
    default:
      return StatusMeta(s, StatusTone.slate);
  }
}

String vehicleTypeLabel(String t) {
  switch (t) {
    case 'ambulance':
      return 'Ambulance';
    case 'wheelchair-van':
      return 'Wheelchair Van';
    case 'van':
      return 'Van';
    case 'car':
      return 'Car';
    case 'minibus':
      return 'Minibus';
    default:
      return t;
  }
}
