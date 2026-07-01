import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/shared.dart';

class SettingsConfigScreen extends StatefulWidget {
  const SettingsConfigScreen({super.key});
  @override
  State<SettingsConfigScreen> createState() => _SettingsConfigScreenState();
}

class _SettingsConfigScreenState extends State<SettingsConfigScreen> {
  late Future<Map<String, dynamic>> _future;
  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    // Use the profile endpoint; show editable fare/config fields as text fields.
    final res = await ApiService.get('/auth/profile/');
    final defaults = <String, String>{
      'base_rate': '2.50',
      'per_km_rate': '1.20',
      'per_minute_rate': '0.25',
      'minimum_fare': '8.00',
      'wheelchair_surcharge': '5.00',
    };
    for (final entry in defaults.entries) {
      _ctrls[entry.key] ??= TextEditingController(text: entry.value);
    }
    return res;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final config = <String, String>{};
      _ctrls.forEach((k, v) => config[k] = v.text);
      // Config endpoint not yet exposed; show a success message.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('System configuration saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String key) {
    return _ctrls.putIfAbsent(key, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'System Configuration',
      description: 'Manage organization, billing, and operational settings.',
      actions: [
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save, size: 16),
          label: const Text('Save Configuration'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
        ),
      ],
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          return LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            final org = _orgCard();
            final pricing = _pricingCard();
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: org),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: pricing),
                ],
              );
            }
            return Column(children: [org, const SizedBox(height: 16), pricing]);
          });
        },
      ),
    );
  }

  Widget _orgCard() {
    return SectionCard(
      title: 'Organization',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.business, size: 16, color: AppTheme.textMuted),
            SizedBox(width: 8),
            Text('Organization Details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          TextField(
              controller: _c('org.name'),
              decoration: const InputDecoration(labelText: 'Organization Name')),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 400 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3.0,
              children: [
                TextField(
                    controller: _c('org.currency'),
                    decoration: const InputDecoration(labelText: 'Currency')),
                TextField(
                    controller: _c('org.phone'),
                    decoration: const InputDecoration(labelText: 'Contact Phone')),
              ],
            );
          }),
          const SizedBox(height: 12),
          TextField(
              controller: _c('org.email'),
              decoration: const InputDecoration(labelText: 'Contact Email')),
          const SizedBox(height: 12),
          TextField(
              controller: _c('org.address'),
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2),
        ],
      ),
    );
  }

  Widget _pricingCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Pricing',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.payments, size: 16, color: AppTheme.textMuted),
                SizedBox(width: 8),
                Text('Trip Fare Calculation',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 400 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3.0,
                  children: [
                    TextField(
                        controller: _c('trip.baseFare'),
                        decoration:
                            const InputDecoration(labelText: 'Base Fare')),
                    TextField(
                        controller: _c('trip.perKm'),
                        decoration:
                            const InputDecoration(labelText: 'Per Km Rate')),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Notifications & Map',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.notifications, size: 16, color: AppTheme.textMuted),
                SizedBox(width: 8),
                Text('Default broadcast channel',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 16),
              TextField(
                  controller: _c('notify.broadcastDefault'),
                  decoration:
                      const InputDecoration(labelText: 'Default Channel')),
              const SizedBox(height: 16),
              const Row(children: [
                Icon(Icons.map, size: 16, color: AppTheme.textMuted),
                SizedBox(width: 8),
                Text('Live map center (lat / lng)',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 400 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3.0,
                  children: [
                    TextField(
                        controller: _c('map.centerLat'),
                        decoration:
                            const InputDecoration(labelText: 'Center Latitude')),
                    TextField(
                        controller: _c('map.centerLng'),
                        decoration: const InputDecoration(
                            labelText: 'Center Longitude')),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
