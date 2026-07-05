import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class PatientsListScreen extends StatefulWidget {
  final NavState nav;
  const PatientsListScreen({super.key, required this.nav});
  @override
  State<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends State<PatientsListScreen> {
  late Future<List<Patient>> _future;
  String _activeFilter = 'all';
  String _search = '';
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  Future<List<Patient>> _load() async {
    final items = await ApiService.list('/patients/profiles/');
    var patients = items.map(Patient.fromJson).toList();
    if (_activeFilter != 'all') {
      final wantActive = _activeFilter == 'active';
      patients = patients.where((p) => p.active == wantActive).toList();
    }
    return patients;
  }

  Future<void> _toggle(Patient p) async {
    try {
      await ApiService.patch('/patients/profiles/${p.id}/', {'active': !p.active});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${p.name} ${p.active ? "deactivated" : "activated"}')));
      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Patients',
      description: 'Manage registered patients and their access status.',
      actions: [_activeDropdown()],
      child: FutureBuilder<List<Patient>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          var rows = snap.data ?? [];
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            rows = rows
                .where((p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.phone.toLowerCase().contains(q) ||
                    (p.address?.toLowerCase().contains(q) ?? false))
                .toList();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchField(
                  hintText: 'Search patients...',
                  onChanged: (v) => setState(() => _search = v)),
              const SizedBox(height: 16),
              DataTable2<Patient>(
                columns: const [
                  DataColumn2(label: 'Patient', key: 'patient', width: 200),
                  DataColumn2(label: 'Age', key: 'age', width: 70, hideOnSmall: true),
                  DataColumn2(label: 'Address', key: 'address', width: 200, hideOnSmall: true),
                  DataColumn2(label: 'Special Needs', key: 'needs', width: 150, hideOnSmall: true),
                  DataColumn2(label: 'Registered', key: 'registered', width: 120, hideOnSmall: true),
                  DataColumn2(label: 'Status', key: 'status', width: 100),
                  DataColumn2(label: '', key: 'actions', width: 60),
                ],
                rows: rows,
                rowKey: (p) => p.id,
                onRowTap: (p) => widget.nav.openDetail('patient', p.id),
                cellValues: (p) => [
                  Row(children: [
                    AvatarCircle(name: p.name, color: AppTheme.primary, size: 32),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(p.phone,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                    ]),
                  ]),
                  p.age != null ? '${p.age} · ${p.gender ?? ""}' : '—',
                  (p.address != null && p.address!.isNotEmpty)
                      ? p.address!
                      : (p.email ?? '—'),
                  p.specialNeeds == null || p.specialNeeds!.isEmpty
                      ? const Text('—',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted))
                      : Wrap(
                          spacing: 4,
                          children: p.specialNeeds!
                              .map((n) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDE9FE),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(n,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF6D28D9))),
                                  ))
                              .toList(),
                        ),
                  formatDate(p.createdAt),
                  () {
                    return StatusBadge(
                        tone: p.active ? StatusTone.green : StatusTone.slate,
                        label: p.active ? 'Active' : 'Inactive',
                        dot: true);
                  }(),
                  TextButton(
                    onPressed: () => _toggle(p),
                    child: Text(p.active ? 'Deactivate' : 'Activate',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
                emptyMessage: 'No patients found.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _activeDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: _activeFilter,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All patients')),
          DropdownMenuItem(value: 'true', child: Text('Active only')),
          DropdownMenuItem(value: 'false', child: Text('Inactive only')),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _activeFilter = v);
          _future = _load();
        },
      ),
    );
  }
}
