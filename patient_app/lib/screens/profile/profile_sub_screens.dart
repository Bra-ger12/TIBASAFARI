import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';
import 'package:patient_app/models/auth_session.dart';
import 'package:url_launcher/url_launcher.dart';

const Color cTeal = AppColors.primary;
const Color cTealDark = AppColors.primaryDark;
const Color cTealDeep = AppColors.primaryDeep;
const Color cTealLight = AppColors.primaryExtraLight;
const Color cBorder = AppColors.border;
const Color cDivider = AppColors.divider;
const Color cMuted = AppColors.textSecondary;
const Color cMutedLight = AppColors.textMuted;
const Color cError = AppColors.error;
const Color cAmber = AppColors.accent;
const Color cBg = AppColors.background;
const Color cBlue = AppColors.secondary;

// --- REUSABLE BASE SETTINGS LAYOUT ---
class _BaseSettingsScreen extends StatefulWidget {
  final String title;
  final List<Widget> children;

  const _BaseSettingsScreen({required this.title, required this.children});

  @override
  State<_BaseSettingsScreen> createState() => _BaseSettingsScreenState();
}

class _BaseSettingsScreenState extends State<_BaseSettingsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

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
                color: Colors.white,
                border: Border(bottom: BorderSide(color: cDivider)),
                boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))],
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
                  Text(widget.title, style: AppFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: cTealDeep)),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: cTeal))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widget.children),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- REUSABLE WIDGETS ---
Widget _settingsGroup({required List<Widget> children}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: cBorder),
      boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: Column(children: children),
  );
}

Widget _settingsTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap, Widget? trailing}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 22, color: cTealDark)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cTealDeep)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12.5, color: cMutedLight, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, size: 20, color: cMutedLight),
          ],
        ),
      ),
    ),
  );
}

Widget _emptyState({required IconData icon, required String title, required String subtitle, String? buttonText, VoidCallback? onButtonTap}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: cBorder)),
    child: Column(
      children: [
        Container(width: 72, height: 72, decoration: const BoxDecoration(color: cTealLight, shape: BoxShape.circle), child: Icon(icon, size: 36, color: cTeal.withValues(alpha: 0.7))),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cTealDeep)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: cMuted, fontWeight: FontWeight.w500, height: 1.5)),
        if (buttonText != null && onButtonTap != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onButtonTap,
              style: ElevatedButton.styleFrom(backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text(buttonText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ],
    ),
  );
}

// --- 1. PERSONAL INFO ---
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});
  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}
class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final session = await AuthSession.load();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = session.fullName.isNotEmpty ? session.fullName : session.displayName;
      _emailCtrl.text = session.email;
      _phoneCtrl.text = session.phone;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await TripApiService.instance.updateUserProfile({
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
      });
      final session = await AuthSession.load();
      final fullName = _nameCtrl.text.trim();
      await AuthSession.save(session.copyWith(
        fullName: fullName,
        displayName: fullName.split(' ').first,
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: cTeal, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: cError, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSettingsScreen(
      title: 'Personal Information',
      children: [
        _settingsGroup(children: [
          _formField(ctrl: _nameCtrl, icon: Icons.person_outline_rounded, label: 'Full Name', hint: 'Enter your full name'),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(color: cDivider, height: 1)),
          _formField(ctrl: _emailCtrl, icon: Icons.email_outlined, label: 'Email Address', hint: 'Enter email address'),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(color: cDivider, height: 1)),
          _formField(ctrl: _phoneCtrl, icon: Icons.phone_outlined, label: 'Phone Number', hint: 'Enter phone number'),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0, disabledBackgroundColor: cBorder, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _isSaving ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Save Changes', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _formField({required TextEditingController ctrl, required IconData icon, required String label, required String hint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 20, color: cTealDark)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cMutedLight, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                TextField(controller: ctrl, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 14, color: cMutedLight, fontWeight: FontWeight.w400), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cTealDeep)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. MEDICAL PROFILE ---
class MedicalProfileScreen extends StatefulWidget {
  const MedicalProfileScreen({super.key});

  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _documents = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await TripApiService.instance.getPatientProfile();
      final docs = await TripApiService.instance.fetchPatientDocuments();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _documents = docs;
      });
    } catch (_) {
      // Non-fatal: show the empty state if the fetch fails.
    }
  }

  Future<void> _showEditSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedicalInfoSheet(profile: _profile ?? const {}),
    );
    if (saved == true) _load();
  }

  Future<void> _uploadDocument() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: cBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: cTeal),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: cTeal),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await TripApiService.instance.uploadPatientDocument(
        docType: 'MEDICAL_RECORD',
        file: File(picked.path),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Document uploaded'), backgroundColor: cTeal, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: cError,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openDocument(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This document is unavailable'),
          backgroundColor: cError,
          behavior: SnackBarBehavior.floating));
      return;
    }
    final uri = Uri.tryParse(url);
    final launched = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open this document'),
          backgroundColor: cError,
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final hasMedicalInfo = profile != null &&
        (((profile['medical_notes'] as String?)?.isNotEmpty ?? false) ||
            (profile['mobility_needs'] != null && profile['mobility_needs'] != 'NONE') ||
            profile['oxygen_required'] == true ||
            profile['medical_escort_required'] == true ||
            profile['iv_drip_required'] == true);

    return _BaseSettingsScreen(
      title: 'Medical Profile',
      children: [
        if (hasMedicalInfo)
          _settingsGroup(children: [
            if (profile['mobility_needs'] != null && profile['mobility_needs'] != 'NONE')
              _settingsTile(
                icon: Icons.accessible_rounded,
                title: 'Mobility Needs',
                subtitle: _mobilityLabel(profile['mobility_needs'] as String),
                onTap: _showEditSheet,
              ),
            if (profile['oxygen_required'] == true ||
                profile['medical_escort_required'] == true ||
                profile['iv_drip_required'] == true)
              _settingsTile(
                icon: Icons.medical_services_rounded,
                title: 'Medical Requirements',
                subtitle: [
                  if (profile['oxygen_required'] == true) 'Oxygen',
                  if (profile['medical_escort_required'] == true) 'Medical Escort',
                  if (profile['iv_drip_required'] == true) 'IV Drip',
                ].join(' · '),
                onTap: _showEditSheet,
              ),
            if ((profile['medical_notes'] as String?)?.isNotEmpty ?? false)
              _settingsTile(
                icon: Icons.notes_rounded,
                title: 'Medical Notes',
                subtitle: profile['medical_notes'] as String,
                onTap: _showEditSheet,
              ),
          ])
        else
          _emptyState(
            icon: Icons.medical_information_outlined,
            title: 'No Medical Data Yet',
            subtitle: 'Adding your medical profile helps us provide the safest and most comfortable transport experience for you.',
            buttonText: 'Add Medical Info',
            onButtonTap: _showEditSheet,
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Medical Documents', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cTealDeep)),
            TextButton.icon(
              onPressed: _uploading ? null : _uploadDocument,
              icon: _uploading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: cTeal))
                  : const Icon(Icons.upload_file_rounded, size: 18, color: cTeal),
              label: const Text('Upload', style: TextStyle(color: cTeal, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_documents.isEmpty)
          _emptyState(
            icon: Icons.folder_open_rounded,
            title: 'No Documents Uploaded',
            subtitle: 'Upload medical records, prescriptions, or insurance cards so drivers and dispatch can access them if needed.',
          )
        else
          _settingsGroup(
            children: _documents
                .map((doc) => _settingsTile(
                      icon: Icons.description_rounded,
                      title: (doc['doc_type_display'] as String?)?.isNotEmpty == true
                          ? doc['doc_type_display'] as String
                          : (doc['doc_type'] as String? ?? 'Document'),
                      subtitle: (doc['description'] as String?)?.isNotEmpty == true
                          ? doc['description'] as String
                          : null,
                      onTap: () => _openDocument(doc['file'] as String?),
                    ))
                .toList(),
          ),
      ],
    );
  }

  String _mobilityLabel(String value) {
    switch (value) {
      case 'WHEELCHAIR':
        return 'Wheelchair';
      case 'STRETCHER':
        return 'Stretcher';
      case 'WALKER_CRUTCHES':
        return 'Walker / Crutches';
      default:
        return value;
    }
  }
}

class _MedicalInfoSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _MedicalInfoSheet({required this.profile});
  @override
  State<_MedicalInfoSheet> createState() => _MedicalInfoSheetState();
}
class _MedicalInfoSheetState extends State<_MedicalInfoSheet> {
  late final TextEditingController _notesCtrl;
  late String _mobilityNeeds;
  late bool _oxygenRequired;
  late bool _medicalEscortRequired;
  late bool _ivDripRequired;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.profile['medical_notes'] as String? ?? '');
    _mobilityNeeds = widget.profile['mobility_needs'] as String? ?? 'NONE';
    _oxygenRequired = widget.profile['oxygen_required'] as bool? ?? false;
    _medicalEscortRequired = widget.profile['medical_escort_required'] as bool? ?? false;
    _ivDripRequired = widget.profile['iv_drip_required'] as bool? ?? false;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await TripApiService.instance.updatePatientProfile({
        'medical_notes': _notesCtrl.text.trim(),
        'mobility_needs': _mobilityNeeds,
        'oxygen_required': _oxygenRequired,
        'medical_escort_required': _medicalEscortRequired,
        'iv_drip_required': _ivDripRequired,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: cError));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: cBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Medical Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cTealDeep)),
            const SizedBox(height: 20),
            const Text('Mobility Needs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cMutedLight)),
            const SizedBox(height: 8),
            _mobilityChips(),
            const SizedBox(height: 20),
            _switchRow('Oxygen Required', _oxygenRequired, (v) => setState(() => _oxygenRequired = v)),
            _switchRow('Medical Escort Required', _medicalEscortRequired, (v) => setState(() => _medicalEscortRequired = v)),
            _switchRow('IV Drip Required', _ivDripRequired, (v) => setState(() => _ivDripRequired = v)),
            const SizedBox(height: 16),
            const Text('Medical Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cMutedLight)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Diabetes, allergies, blood type',
                hintStyle: const TextStyle(color: cMutedLight),
                filled: true,
                fillColor: cBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontWeight: FontWeight.w600, color: cTealDeep),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Save Information', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobilityChips() {
    const options = [
      ('NONE', 'None'),
      ('WHEELCHAIR', 'Wheelchair'),
      ('STRETCHER', 'Stretcher'),
      ('WALKER_CRUTCHES', 'Walker / Crutches'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = _mobilityNeeds == opt.$1;
        return ChoiceChip(
          label: Text(opt.$2),
          selected: selected,
          onSelected: (_) => setState(() => _mobilityNeeds = opt.$1),
          selectedColor: cTeal,
          backgroundColor: cBg,
          labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : cTealDeep),
        );
      }).toList(),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep)),
          Switch(value: value, onChanged: onChanged, activeThumbColor: cTeal),
        ],
      ),
    );
  }
}

// --- 3. EMERGENCY CONTACTS ---
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await AuthSession.load();
    if (mounted) setState(() => _session = session);
  }

  Future<void> _showEditSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactSheet(
        initialName: _session?.emergencyContactName ?? '',
        initialPhone: _session?.emergencyContactPhone ?? '',
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final hasContact = session != null && session.emergencyContactName.isNotEmpty;

    return _BaseSettingsScreen(
      title: 'Emergency Contacts',
      children: [
        if (hasContact)
          _settingsGroup(children: [
            _settingsTile(
              icon: Icons.contact_phone_rounded,
              title: session.emergencyContactName,
              subtitle: session.emergencyContactPhone,
              onTap: _showEditSheet,
            ),
          ])
        else
          _emptyState(
            icon: Icons.contact_phone_outlined,
            title: 'No Contacts Added',
            subtitle: 'In case of an emergency during a trip, we will notify these contacts immediately.',
            buttonText: 'Add Emergency Contact',
            onButtonTap: _showEditSheet,
          ),
      ],
    );
  }
}

class _ContactSheet extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  const _ContactSheet({this.initialName = '', this.initialPhone = ''});
  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}
class _ContactSheetState extends State<_ContactSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter both name and phone'), backgroundColor: cError));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await TripApiService.instance.updatePatientProfile({
        'emergency_contact_name': _nameCtrl.text.trim(),
        'emergency_contact_phone': _phoneCtrl.text.trim(),
      });
      final session = await AuthSession.load();
      await AuthSession.save(session.copyWith(
        emergencyContactName: _nameCtrl.text.trim(),
        emergencyContactPhone: _phoneCtrl.text.trim(),
      ));
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact saved successfully'), backgroundColor: cTeal, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: cError));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: cBorder, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Emergency Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cTealDeep)),
          const SizedBox(height: 20),
          _sheetField(ctrl: _nameCtrl, label: 'Full Name', hint: 'Contact name'),
          _sheetField(ctrl: _phoneCtrl, label: 'Phone Number', hint: '+255 7XX XXX XXX'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0, disabledBackgroundColor: cBorder, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _isSaving
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Save Contact', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField({required TextEditingController ctrl, required String label, required String hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cMutedLight)),
        const SizedBox(height: 8),
        TextField(controller: ctrl, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: cMutedLight), filled: true, fillColor: cBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), style: const TextStyle(fontWeight: FontWeight.w600, color: cTealDeep)),
      ]),
    );
  }
}

// --- 5. NOTIFICATIONS ---
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}
class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _rides = true;
  bool _promo = false;
  bool _security = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await TripApiService.instance.getNotificationPreferences();
      if (!mounted) return;
      setState(() {
        _rides = prefs['ride_updates'] as bool? ?? true;
        _promo = prefs['promotions'] as bool? ?? false;
        _security = prefs['security_alerts'] as bool? ?? true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String type, bool val) async {
    setState(() {
      if (type == 'rides') _rides = val;
      if (type == 'promo') _promo = val;
      if (type == 'security') _security = val;
    });
    try {
      await TripApiService.instance.updateNotificationPreferences({
        if (type == 'rides') 'ride_updates': val,
        if (type == 'promo') 'promotions': val,
        if (type == 'security') 'security_alerts': val,
      });
      if (mounted) {
        const labels = {'rides': 'Ride', 'promo': 'Promo', 'security': 'Security'};
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${labels[type] ?? type} preferences updated'), backgroundColor: cTeal, behavior: SnackBarBehavior.floating, duration: const Duration(milliseconds: 1500))
        );
      }
    } catch (e) {
      if (mounted) {
        // Revert optimistic toggle on failure.
        setState(() {
          if (type == 'rides') _rides = !val;
          if (type == 'promo') _promo = !val;
          if (type == 'security') _security = !val;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: cError, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSettingsScreen(
      title: 'Notifications',
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: cTeal)),
          )
        else
          _settingsGroup(children: [
            _switchTile(icon: Icons.directions_car_rounded, title: 'Ride Updates', subtitle: 'Driver assigned, arrival times, status', value: _rides, onChanged: (v) => _toggle('rides', v)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(color: cDivider, height: 1)),
            _switchTile(icon: Icons.local_offer_outlined, title: 'Promotions', subtitle: 'Discounts, offers, and rewards', value: _promo, onChanged: (v) => _toggle('promo', v)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(color: cDivider, height: 1)),
            _switchTile(icon: Icons.shield_outlined, title: 'Security Alerts', subtitle: 'Login attempts and password changes', value: _security, onChanged: (v) => _toggle('security', v)),
          ]),
      ],
    );
  }

  Widget _switchTile({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 22, color: cTealDark)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cTealDeep)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: cMutedLight, fontWeight: FontWeight.w500)),
          ])),
          Switch(value: value, onChanged: onChanged, activeThumbColor: cTeal, inactiveTrackColor: cBorder),
        ],
      ),
    );
  }
}

// --- 6. PRIVACY & SECURITY ---
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  void _showPasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PasswordSheet(),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w800, color: cTealDeep)),
        content: const Text('This action is irreversible. All your data, trip history, and medical profiles will be permanently deleted.', style: TextStyle(color: cMuted, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: cMuted, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion requested.'), backgroundColor: cError)); },
            style: ElevatedButton.styleFrom(backgroundColor: cError, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSettingsScreen(
      title: 'Privacy & Security',
      children: [
        _settingsGroup(children: [
          _settingsTile(icon: Icons.lock_outline_rounded, title: 'Change Password', subtitle: 'Update your account password', onTap: () => _showPasswordSheet(context)),
        ]),
        _settingsGroup(children: [
          _settingsTile(icon: Icons.delete_outline_rounded, title: 'Delete Account', subtitle: 'Permanently delete your data', onTap: () => _showDeleteDialog(context), trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: cError)),
        ]),
      ],
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();
  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}
class _PasswordSheetState extends State<_PasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: cBorder, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cTealDeep)),
          const SizedBox(height: 20),
          _sheetField(ctrl: _currentCtrl, label: 'Current Password', hint: '••••••••', isPassword: true),
          _sheetField(ctrl: _newCtrl, label: 'New Password', hint: '••••••••', isPassword: true),
          _sheetField(ctrl: _confirmCtrl, label: 'Confirm New Password', hint: '••••••••', isPassword: true),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully'), backgroundColor: cTeal, behavior: SnackBarBehavior.floating)); }, style: ElevatedButton.styleFrom(backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.w700)))),
        ],
      ),
    );
  }

  Widget _sheetField({required TextEditingController ctrl, required String label, required String hint, bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cMutedLight)),
        const SizedBox(height: 8),
        TextField(obscureText: isPassword, controller: ctrl, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: cMutedLight), filled: true, fillColor: cBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), style: const TextStyle(fontWeight: FontWeight.w600, color: cTealDeep)),
      ]),
    );
  }
}

// --- 7. HELP & SUPPORT ---
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  void _showActionDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: cTealDeep)),
        content: Text(content, style: const TextStyle(color: cMuted, height: 1.5)),
        actions: [
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.w700)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSettingsScreen(
      title: 'Help & Support',
      children: [
        _settingsGroup(children: [
          _settingsTile(icon: Icons.chat_bubble_outline_rounded, title: 'Live Chat', subtitle: 'Chat with our support team', onTap: () => _showActionDialog(context, 'Live Chat', 'Connecting you to a live agent. Please hold...')),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(color: cDivider, height: 1)),
          _settingsTile(icon: Icons.phone_outlined, title: 'Call Us', subtitle: 'Speak directly with support', onTap: () => _showActionDialog(context, 'Call Support', 'Please dial our toll-free support line to speak with an agent immediately.')),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(color: cDivider, height: 1)),
          _settingsTile(icon: Icons.email_outlined, title: 'Email Support', subtitle: 'Send us a detailed message', onTap: () => _showActionDialog(context, 'Email Support', 'A support ticket will be created. We typically respond within 24 hours.')),
        ]),
        _settingsGroup(children: [
          _settingsTile(icon: Icons.description_outlined, title: 'Terms of Service', onTap: () => _showActionDialog(context, 'Terms of Service', 'Redirecting to our hosted Terms of Service agreement...')),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(color: cDivider, height: 1)),
          _settingsTile(icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', onTap: () => _showActionDialog(context, 'Privacy Policy', 'Redirecting to our hosted Privacy Policy document...')),
        ]),
      ],
    );
  }
}

// --- 8. ABOUT ---
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _showActionSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cTeal, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSettingsScreen(
      title: 'About Tiba Safari',
      children: [
        Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [cTeal, cTealDark]), borderRadius: BorderRadius.all(Radius.circular(22)), boxShadow: [BoxShadow(color: Color(0x331D9E75), blurRadius: 12, offset: Offset(0, 4))]),
                child: const Icon(Icons.local_hospital_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('Tiba Safari', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cTealDeep)),
              const SizedBox(height: 4),
              const Text('Version 1.0.0 (Build 1)', style: TextStyle(fontSize: 13, color: cMutedLight, fontWeight: FontWeight.w500)),
              const SizedBox(height: 30),
              _settingsGroup(children: [
                _settingsTile(icon: Icons.star_outline_rounded, title: 'Rate Us on App Store', onTap: () => _showActionSnackBar(context, 'Redirecting to App Store...')),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(color: cDivider, height: 1)),
                _settingsTile(icon: Icons.share_outlined, title: 'Share Tiba Safari', onTap: () => _showActionSnackBar(context, 'Share sheet opened')),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(color: cDivider, height: 1)),
                _settingsTile(icon: Icons.file_copy_outlined, title: 'Licenses', onTap: () => _showActionSnackBar(context, 'Opening licenses...')),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}