import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../services/driver_service.dart';

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  static const _docTypes = [
    ('LICENSE', "Driver's License", Icons.badge_outlined),
  ];

  bool _isLoading = true;
  String? _error;
  Map<String, Map<String, dynamic>> _latestByType = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final docs = await DriverService.instance.fetchDriverDocuments();
      final byType = <String, Map<String, dynamic>>{};
      for (final doc in docs) {
        final type = doc['doc_type'] as String?;
        if (type == null) continue;
        // Docs come back newest-first; keep the first (latest) per type.
        byType.putIfAbsent(type, () => doc);
      }
      if (mounted) setState(() { _latestByType = byType; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _upload(String docType) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: cSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: cBorder, borderRadius: BorderRadius.circular(2)),
            ),
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

    setState(() => _isLoading = true);
    try {
      await DriverService.instance.uploadDriverDocument(
        docType: docType,
        file: File(picked.path),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Document submitted for review'),
          backgroundColor: cTeal,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: cError,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
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
                color: cSurface,
                border: Border(bottom: BorderSide(color: cBorder)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_rounded, size: 22, color: cTealDark),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Documents & Compliance', style: AppFonts.sora(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: cTeal))
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: cTeal,
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: _docTypes
                                .map((t) => Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: _buildDocCard(t.$1, t.$2, t.$3),
                                    ))
                                .toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: cError),
          const SizedBox(height: 16),
          Text(_error ?? '', style: const TextStyle(fontSize: 14, color: cMuted), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: cTeal, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDocCard(String docType, String title, IconData icon) {
    final doc = _latestByType[docType];
    final status = doc?['status'] as String? ?? 'NOT_UPLOADED';
    final (label, bg, fg) = switch (status) {
      'VERIFIED' => ('Verified', cTealLight, cTealDark),
      'PENDING' => ('Pending Review', const Color(0xFFFFFBEB), cAmber),
      'REJECTED' => ('Rejected', const Color(0xFFFEF2F2), cError),
      _ => ('Not Uploaded', cBg, cMutedLight),
    };
    final uploadedAt = DateTime.tryParse(doc?['uploaded_at']?.toString() ?? '');
    final rejectionReason = doc?['rejection_reason'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, size: 22, color: cTealDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cText)),
                if (uploadedAt != null) ...[
                  const SizedBox(height: 2),
                  Text('Uploaded ${DateFormat('MMM d, yyyy').format(uploadedAt.toLocal())}',
                      style: const TextStyle(fontSize: 12, color: cMutedLight)),
                ],
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
            ),
          ]),
          if (status == 'REJECTED' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
              child: Text(rejectionReason, style: const TextStyle(fontSize: 12.5, color: cError)),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _upload(docType),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(doc == null ? 'Upload' : 'Replace', style: const TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: cTealDark,
                side: const BorderSide(color: cBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
