// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class DriverProfileScreen extends StatefulWidget {
  final NavState nav;
  const DriverProfileScreen({super.key, required this.nav});
  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  Future<Map<String, dynamic>> _load() async {
    final driverId = widget.nav.selectedDriverId;
    final profile = await ApiService.get('/drivers/profiles/$driverId/');
    // Load recent trips for this driver
    final tripItems = await ApiService.list('/trips/?driver=$driverId&limit=10')
        .catchError((_) => <Map<String, dynamic>>[]);
    final completedCount = tripItems
        .where((t) => (t['status'] as String?) == 'COMPLETED')
        .length;
    return {
      'driver': profile,
      'trips': tripItems,
      'stats': <String, dynamic>{
        'totalTrips': profile['trips_count'] ?? tripItems.length,
        'completedTrips': completedCount,
        'avgRating': profile['rating'] ?? 0,
        'totalRevenue': profile['revenue'] ?? 0,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingRows();
        }
        final d = Driver.fromJson(snap.data!['driver'] as Map<String, dynamic>);
        final trips = (snap.data!['trips'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Trip.fromJson)
            .toList();
        final stats = snap.data!['stats'] as Map<String, dynamic>;
        final meta = driverStatus(d.status);
        return PageScaffold(
          title: d.name,
          description: d.licenseNumber,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => widget.nav.navigate(ViewKey.driversList),
          ),
          actions: [
            StatusBadge(tone: meta.tone, label: meta.label, dot: true),
            OutlinedButton.icon(
              onPressed: () => _showVehicleDialog(d),
              icon: const Icon(Icons.directions_car, size: 16),
              label: const Text('Assign Vehicle'),
            ),
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(d),
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Remove', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red)),
            ),
          ],
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            final left = _left(d);
            final right = _right(d, trips, stats);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: left),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: right),
                ],
              );
            }
            return Column(children: [left, const SizedBox(height: 16), right]);
          }),
        );
      },
    );
  }

  Widget _left(Driver d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Profile',
          child: Column(children: [
            AvatarCircle(
                name: d.name, color: avatarColor(d.avatarColor), size: 56),
            const SizedBox(height: 12),
            Text(d.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star, size: 14, color: Colors.amber[600]),
              const SizedBox(width: 4),
              Text('${d.rating.toStringAsFixed(1)} rating',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted)),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _infoLine(Icons.phone, d.phone),
            _infoLine(Icons.email, d.email),
            _infoLine(Icons.badge, d.licenseNumber),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Assigned Vehicle',
          child: d.vehicle == null
              ? const Text('No vehicle assigned.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted))
              : Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),  // ✅ FIXED
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_car,
                        size: 18, color: Color(0xFF0EA5E9)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(d.vehicle!.plate,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                            d.vehicle!.model.isEmpty
                                ? vehicleTypeLabel(d.vehicle!.type)
                                : '${d.vehicle!.model} · ${vehicleTypeLabel(d.vehicle!.type)}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                      ])),
                  () {
                    final m = vehicleStatus(d.vehicle!.status);
                    return StatusBadge(
                        tone: m.tone, label: m.label, dot: true);
                  }(),
                ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Documents & Compliance',
          child: d.documents.isEmpty
              ? const Text('No documents submitted yet.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted))
              : Column(
                  children: d.documents
                      .map((doc) => _buildDocumentRow(d, doc))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildDocumentRow(Driver d, DriverDocument doc) {
    final (label, color) = switch (doc.status) {
      'VERIFIED' => ('Verified', Colors.green),
      'REJECTED' => ('Rejected', Colors.red),
      _ => ('Pending Review', Colors.amber[800]!),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  doc.docTypeDisplay.isNotEmpty ? doc.docTypeDisplay : doc.docType,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              StatusBadge(
                tone: doc.status == 'VERIFIED'
                    ? StatusTone.green
                    : doc.status == 'REJECTED'
                        ? StatusTone.red
                        : StatusTone.amber,
                label: label,
                dot: true,
              ),
            ],
          ),
          if (doc.fileUrl != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => html.window.open(doc.fileUrl!, '_blank'),
              child: Text('View document',
                  style: TextStyle(fontSize: 12, color: color, decoration: TextDecoration.underline)),
            ),
          ],
          if (doc.status == 'REJECTED' && doc.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(doc.rejectionReason,
                style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
          if (doc.status == 'PENDING') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => _reviewDocument(d, doc, verified: true),
                  child: const Text('Verify'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _reviewDocument(d, doc, verified: false),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reviewDocument(Driver d, DriverDocument doc, {required bool verified}) async {
    String reason = '';
    if (!verified) {
      reason = await showDialog<String>(
            context: context,
            builder: (ctx) {
              final controller = TextEditingController();
              return AlertDialog(
                title: const Text('Reject Document'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Reason for rejection'),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    child: const Text('Reject'),
                  ),
                ],
              );
            },
          ) ??
          '';
      if (reason.isEmpty) return;
    }
    try {
      await ApiService.patch(
        '/drivers/profiles/${d.id}/documents/${doc.id}/review/',
        {
          'status': verified ? 'VERIFIED' : 'REJECTED',
          'rejection_reason': reason,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(verified ? 'Document verified.' : 'Document rejected.')));
        setState(() => _future = _load());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _infoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _right(Driver d, List<Trip> trips, Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 700 ? 4 : 2;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _statCard(Icons.badge, 'Total Trips',
                  stats['totalTrips'].toString(), const Color(0xFF0EA5E9)),
              _statCard(Icons.check_circle, 'Completed',
                  stats['completedTrips'].toString(), AppTheme.primary),
              _statCard(Icons.star, 'Avg Rating',
                  (stats['avgRating'] as num).toStringAsFixed(1),
                  const Color(0xFFF59E0B)),
              _statCard(Icons.trending_up, 'Revenue',
                  formatCurrency((stats['totalRevenue'] as num).toDouble()),
                  const Color(0xFF7C3AED)),
            ],
          );
        }),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Trip History',
          padding: const EdgeInsets.all(16),
          child: trips.isEmpty
              ? const EmptyState(
                  icon: Icons.history, title: 'No trips recorded.')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: trips.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppTheme.border),
                  itemBuilder: (context, i) {
                    final t = trips[i];
                    final m = tripStatus(t.status);
                    return ListTile(
                      dense: true,
                      onTap: () => widget.nav.openDetail('trip', t.id),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.reference,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          StatusBadge(tone: m.tone, label: m.label, dot: true),
                        ],
                      ),
                      subtitle: Text(
                          '${formatDate(t.startedAt)} · ${formatCurrency(t.fare)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _statCard(
      IconData icon, String label, String value, Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),  // ✅ FIXED
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showVehicleDialog(Driver d) {
    showDialog(
      context: context,
      builder: (_) => _VehicleAssignDialog(driverId: d.id, currentVehicle: d.vehicle),
    ).then((_) {
      setState(() => _future = _load());
    });
  }

  Future<void> _confirmDelete(Driver d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Driver?'),
        content: Text(
            'This removes ${d.name}\'s driver profile (license, vehicle assignment, availability). '
            'Their user account and trip history are not affected. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.delete('/drivers/profiles/${d.id}/');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${d.name} removed.')));
      widget.nav.navigate(ViewKey.driversList);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _VehicleAssignDialog extends StatefulWidget {
  final String driverId;
  final Vehicle? currentVehicle;
  const _VehicleAssignDialog(
      {required this.driverId, required this.currentVehicle});

  @override
  State<_VehicleAssignDialog> createState() => _VehicleAssignDialogState();
}

class _VehicleAssignDialogState extends State<_VehicleAssignDialog> {
  List<Vehicle> _vehicles = [];
  String? _selected;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.list('/operations/vehicles/');
      _vehicles = items.map(Vehicle.fromJson).toList();
      _selected = widget.currentVehicle?.id;
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.patch('/drivers/profiles/${widget.driverId}/',
          {'vehicle': _selected ?? ''});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle assignment updated.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign Vehicle',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String?>(
                      initialValue: _selected,
                      decoration: const InputDecoration(
                          labelText: 'Vehicle',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('No vehicle')),
                        ..._vehicles.map((v) => DropdownMenuItem<String?>(
                              value: v.id,
                              child: Text(
                                  '${v.plate} · ${v.model} (${v.status})'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selected = v),
                    ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary),
                    child: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}