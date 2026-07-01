import 'package:flutter/material.dart';

import '../../core/models/driver_session.dart';
import '../../core/theme/colors.dart';
import '../../services/driver_service.dart';

// ── Shared base layout (mirrors patient_app's settings screens) ──────────────

class _BaseSettingsScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _BaseSettingsScreen({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: cSurface,
                border: Border(bottom: BorderSide(color: cBorder)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_rounded, size: 22, color: cTealDark),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(title, style: AppFonts.sora(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _card({required List<Widget> children}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: cSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: cBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

Widget _field({
  required TextEditingController ctrl,
  required String label,
  required IconData icon,
  bool enabled = true,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, size: 20, color: cTealDark),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cMutedLight, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              TextField(
                controller: ctrl,
                enabled: enabled,
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: enabled ? cText : cMutedLight),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Edit Profile ──────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  final DriverSession session;
  const EditProfileScreen({super.key, required this.session});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.session.displayName);
    _emailCtrl = TextEditingController(text: widget.session.email);
    _phoneCtrl = TextEditingController(text: widget.session.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _isSaving = true; _error = null; });
    try {
      await DriverService.instance.updateUserProfile({
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSettingsScreen(
      title: 'Edit Profile',
      children: [
        _card(children: [
          _field(ctrl: _nameCtrl, label: 'Full Name', icon: Icons.person_outline_rounded),
          const Divider(color: cDivider, height: 24),
          _field(ctrl: _emailCtrl, label: 'Email Address', icon: Icons.email_outlined),
          const Divider(color: cDivider, height: 24),
          _field(ctrl: _phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cError.withValues(alpha: 0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: cError, fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0,
              disabledBackgroundColor: cBorder,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSaving
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Save Changes', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ── My Vehicle ────────────────────────────────────────────────────────────────

class MyVehicleScreen extends StatefulWidget {
  final DriverSession session;
  const MyVehicleScreen({super.key, required this.session});

  @override
  State<MyVehicleScreen> createState() => _MyVehicleScreenState();
}

class _MyVehicleScreenState extends State<MyVehicleScreen> {
  late final TextEditingController _licenseCtrl;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _licenseCtrl = TextEditingController(text: widget.session.licenseNumber);
  }

  @override
  void dispose() {
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _isSaving = true; _error = null; });
    try {
      await DriverService.instance.updateDriverProfile({
        'license_number': _licenseCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSettingsScreen(
      title: 'My Vehicle',
      children: [
        _card(children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.directions_car_rounded, size: 20, color: cTealDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.session.vehiclePlate.isEmpty ? 'Not assigned' : widget.session.vehiclePlate,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cText)),
                const SizedBox(height: 2),
                Text(widget.session.vehicleType.displayName,
                    style: const TextStyle(fontSize: 12.5, color: cMutedLight)),
              ]),
            ),
          ]),
        ]),
        const SizedBox(height: 16),
        _card(children: [
          _field(ctrl: _licenseCtrl, label: 'License Number', icon: Icons.badge_outlined),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cTealLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: cTealDark),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vehicle assignment and details are managed by dispatch. Contact support to update your vehicle.',
                style: TextStyle(fontSize: 12, color: cTealDark, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cError.withValues(alpha: 0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: cError, fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0,
              disabledBackgroundColor: cBorder,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSaving
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Save Changes', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ── Help & Support (dialog-based, mirrors patient_app's pattern) ─────────────

class DriverHelpSupportScreen extends StatelessWidget {
  const DriverHelpSupportScreen({super.key});

  void _showActionDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: cText)),
        content: Text(content, style: const TextStyle(color: cMuted, height: 1.5)),
        actions: [
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSettingsScreen(
      title: 'Help & Support',
      children: [
        _card(children: [
          _helpTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Live Chat',
            subtitle: 'Chat with dispatch support',
            onTap: () => _showActionDialog(context, 'Live Chat', 'Connecting you to a dispatch agent. Please hold...'),
          ),
          const Divider(color: cDivider, height: 24),
          _helpTile(
            icon: Icons.phone_outlined,
            title: 'Call Dispatch',
            subtitle: 'Speak directly with dispatch',
            onTap: () => _showActionDialog(context, 'Call Dispatch', 'Please dial the dispatch support line to speak with an agent immediately.'),
          ),
          const Divider(color: cDivider, height: 24),
          _helpTile(
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: 'Send a detailed message',
            onTap: () => _showActionDialog(context, 'Email Support', 'A support ticket will be created. We typically respond within 24 hours.'),
          ),
        ]),
      ],
    );
  }

  Widget _helpTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 20, color: cTealDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cText)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: cMutedLight, fontWeight: FontWeight.w500)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: cMutedLight),
        ]),
      ),
    );
  }
}
