import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';
import '../widgets/assign_driver_dialog.dart';

class BookingDetailScreen extends StatefulWidget {
  final NavState nav;
  const BookingDetailScreen({super.key, required this.nav});
  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  List<Driver> _allDrivers = [];
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    return ApiService.get('/trips/${widget.nav.selectedBookingId}/');
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _loadDrivers() async {
    if (_allDrivers.isNotEmpty) return;
    try {
      final items = await ApiService.list('/drivers/profiles/');
      _allDrivers = items.map(Driver.fromJson).toList();
    } catch (_) {}
  }

  Future<void> _cancelBooking(Booking b) async {
    setState(() => _actionLoading = true);
    try {
      // Goes through the real cancel action (TripService.cancel_trip) so
      // driver availability is restored and notifications/WS pushes fire —
      // a raw PATCH {'status': 'cancelled'} would both bypass all of that
      // and be rejected outright, since Trip.status choices are uppercase.
      await ApiService.post('/trips/${b.id}/cancel/', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip ${b.reference} cancelled')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _assign(String driverId) async {
    final tripId = widget.nav.selectedBookingId ?? '';
    setState(() => _actionLoading = true);
    try {
      await ApiService.post(
          '/trips/$tripId/assign-driver/', {'driver_id': driverId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver assigned.')));
      if (!mounted) return;
      Navigator.of(context).pop();
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingRows();
        }
        if (snap.hasError || snap.data == null) {
          return ErrorState(message: '${snap.error ?? 'Unknown error'}', onRetry: _reload);
        }
        final b = Booking.fromJson(snap.data!);
        final meta = bookingStatus(b.status);
        // Trip.status values from the backend are uppercase (REQUESTED,
        // ASSIGNED, ACCEPTED, EN_ROUTE, ARRIVED, COMPLETED, CANCELLED) —
        // there is no "pending"/"approved" status, so this used to always
        // evaluate false and the Assign Driver button never rendered.
        // Assigning a driver is only valid while a trip is still REQUESTED
        // (see TripService.assign_driver).
        final canAct = b.status == 'REQUESTED';
        return PageScaffold(
          title: b.reference,
          description: 'Created ${formatDate(b.createdAt, withTime: true)}',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => widget.nav.navigate(ViewKey.bookingsAll),
          ),
          actions: [
            StatusBadge(tone: meta.tone, label: meta.label, dot: true),
          ],
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            final left = _leftColumn(b);
            final right = _rightColumn(b, canAct);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: left),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: right),
                ],
              );
            }
            return Column(children: [left, const SizedBox(height: 16), right]);
          }),
        );
      },
    );
  }

  Widget _leftColumn(Booking b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Trip Details',
          child: LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 500 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3.2,
              children: [
                InfoRow(label: 'Pickup', value: Text(b.pickup)),
                InfoRow(label: 'Drop-off', value: Text(b.dropoff)),
                InfoRow(
                    label: 'Scheduled',
                    value: Text(formatDate(b.scheduledAt, withTime: true))),
                InfoRow(
                    label: 'Fare',
                    value: Text(formatCurrency(b.fare),
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                InfoRow(
                    label: 'Special Needs',
                    value: b.specialNeeds == null || b.specialNeeds!.isEmpty
                        ? const Text('None')
                        : Wrap(
                            spacing: 4,
                            children: b.specialNeeds!
                                .map((n) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE9FE),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(n,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF6D28D9))),
                                    ))
                                .toList(),
                          )),
                InfoRow(
                    label: 'Notes',
                    value: Text(b.notes ?? '—',
                        style: const TextStyle(fontSize: 13))),
              ],
            );
          }),
        ),
        if (b.trip != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Associated Trip',
            action: TextButton(
                onPressed: () => widget.nav.openDetail('trip', b.trip!.id),
                child: const Text('View trip')),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_shipping,
                      size: 18, color: Color(0xFF0EA5E9)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.trip!.reference,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                          'Started ${formatDate(b.trip!.startedAt, withTime: true)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _rightColumn(Booking b, bool canAct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (b.patientName.isNotEmpty)
          SectionCard(
            title: 'Patient',
            child: InkWell(
              onTap: () => widget.nav.openDetail('patient', b.patientId),
              child: Row(
                children: [
                  AvatarCircle(
                      name: b.patientName,
                      color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(b.patientName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Assigned Driver',
          child: b.driver == null
              ? const Text('No driver assigned yet.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted))
              : InkWell(
                  onTap: () => widget.nav.openDetail('driver', b.driver!.id),
                  child: Row(
                    children: [
                      AvatarCircle(
                          name: b.driver!.name,
                          color: avatarColor(b.driver!.avatarColor)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.driver!.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text(b.driver!.phone,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Actions',
          child: Column(
            children: [
              if (canAct) ...[
                OutlinedButton.icon(
                  onPressed: _actionLoading
                      ? null
                      : () async {
                          await _loadDrivers();
                          if (!mounted) return;  // ✅ FIXED
                          showDialog(
                            context: context,
                            builder: (_) => AssignDriverDialog(
                              bookingReference: b.reference,
                              drivers: _allDrivers,
                              loading: _actionLoading,
                              onAssign: _assign,
                            ),
                          );
                        },
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Assign Driver'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40)),
                ),
              ],
              if (b.status != 'COMPLETED' && b.status != 'CANCELLED') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _actionLoading ? null : () => _cancelBooking(b),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE11D48),
                      minimumSize: const Size.fromHeight(40)),
                ),
              ],
              if (b.status == 'COMPLETED' || b.status == 'CANCELLED')
                const Text('No further actions available.',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}