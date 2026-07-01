import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/shared.dart';
import '../widgets/status_badge.dart';

class SettingsProfileScreen extends StatefulWidget {
  const SettingsProfileScreen({super.key});
  @override
  State<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends State<SettingsProfileScreen> {
  late Future<Map<String, dynamic>> _future;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  AdminUser? _admin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final res = await ApiService.get('/auth/profile/');
    final a = AdminUser.fromJson(res);
    _admin = a;
    _name.text = a.name;
    _email.text = a.email;
    _phone.text = a.phone ?? '';
    return res;
  }

  Future<void> _save() async {
    if (_admin == null) return;
    setState(() => _saving = true);
    try {
      await ApiService.patch('/auth/profile/', {
        'full_name': _name.text,
        'phone': _phone.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully.')));
        setState(() => _future = _load());
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
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Admin Profile',
      description: 'Manage your administrator account details.',
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          return LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            final left = SectionCard(
              title: 'Account',
              child: Column(children: [
                AvatarCircle(
                    name: _name.text.isEmpty ? 'A' : _name.text,
                    color: AppTheme.primary,
                    size: 56),
                const SizedBox(height: 12),
                Text(_name.text,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_email.text,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.shield,
                        size: 12, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(_admin?.role ?? 'admin',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                  ]),
                ),
              ]),
            );
            final right = SectionCard(
              title: 'Edit Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 500 ? 2 : 1;
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 3.0,
                      children: [
                        TextField(
                            controller: _name,
                            decoration: const InputDecoration(labelText: 'Full Name')),
                        TextField(
                            controller: _email,
                            decoration: const InputDecoration(labelText: 'Email')),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, size: 16),
                      label: const Text('Save Changes'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            );
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
          });
        },
      ),
    );
  }
}
