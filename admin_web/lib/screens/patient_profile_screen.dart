import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class PatientProfileScreen extends StatefulWidget {
  final NavState nav;
  const PatientProfileScreen({super.key, required this.nav});
  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  Future<Map<String, dynamic>> _load() async {
    final patientId = widget.nav.selectedPatientId;
    final profile =
        await ApiService.get('/patients/profiles/$patientId/');
    final tripItems =
        await ApiService.list('/trips/?patient=$patientId&limit=20')
            .catchError((_) => <Map<String, dynamic>>[]);
    return {'patient': profile, 'trips': tripItems};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingRows();
        }
        final p = Patient.fromJson(snap.data!['patient'] as Map<String, dynamic>);
        final trips = (snap.data!['trips'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Trip.fromJson)
            .toList();
        final totalSpent = trips
            .where((t) => t.status == 'completed')
            .fold(0.0, (s, t) => s + t.fare);
        return PageScaffold(
          title: p.name,
          description: 'Patient since ${formatDate(p.createdAt)}',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => widget.nav.navigate(ViewKey.patientsList),
          ),
          actions: [
            StatusBadge(
                tone: p.active ? StatusTone.green : StatusTone.slate,
                label: p.active ? 'Active' : 'Inactive',
                dot: true),
          ],
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            final left = _left(p);
            final right = _right(p, trips, totalSpent);
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

  Widget _left(Patient p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Profile',
          child: Column(children: [
            AvatarCircle(name: p.name, color: AppTheme.primary, size: 56),
            const SizedBox(height: 12),
            Text(p.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
                '${p.age != null ? "${p.age} yrs" : "—"} · ${p.gender ?? "—"}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _infoLine(Icons.phone, p.phone),
            if (p.email != null) _infoLine(Icons.email, p.email!),
            if (p.address != null) _infoLine(Icons.location_on, p.address!),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Special Needs',
          child: p.specialNeeds == null || p.specialNeeds!.isEmpty
              ? const Text('No special needs recorded.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.specialNeeds!
                      .map((n) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(n,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6D28D9))),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
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

  Widget _right(Patient p, List<Trip> trips, double totalSpent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 600 ? 3 : 1;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: [
              _statCard('Total Trips', trips.length.toString()),
              _statCard('Total Spent', formatCurrency(totalSpent)),
              _statCard('Status', p.active ? 'Active' : 'Inactive'),
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
              : DataTable2<Trip>(
                  columns: const [
                    DataColumn2(label: 'Trip', key: 'reference'),
                    DataColumn2(
                        label: 'Date', key: 'date', hideOnSmall: true),
                    DataColumn2(label: 'Fare', key: 'fare', numeric: true),
                    DataColumn2(label: 'Status', key: 'status'),
                  ],
                  rows: trips,
                  rowKey: (t) => t.id,
                  pageSize: 6,
                  onRowTap: (t) => widget.nav.openDetail('trip', t.id),
                  cellValues: (t) => [
                    Text(t.reference,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    formatDate(t.startedAt),
                    formatCurrency(t.fare),
                    () {
                      final m = tripStatus(t.status);
                      return StatusBadge(
                          tone: m.tone, label: m.label, dot: true);
                    }(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
