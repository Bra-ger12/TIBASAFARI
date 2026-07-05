import 'dart:async';

import 'package:flutter/material.dart';
import 'package:patient_app/core/services/facility_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';
import 'package:patient_app/models/facility.dart';

const Color _cTeal = AppColors.primary;
const Color _cTealDeep = AppColors.primaryDeep;
const Color _cMuted = AppColors.textSecondary;
const Color _cError = AppColors.error;
const Color _cBorder = AppColors.border;

/// Autocomplete search over our own free, OSM-seeded facility database
/// (GET /facilities/search/) — replaces the Google Places picker, which
/// needs billing we don't have enabled. Used for both destination search
/// and pickup search (e.g. a discharge trip picked up from a hospital).
/// Returns the selected [Facility] (name + lat/lng) to the booking screen.
class FacilitySearchScreen extends StatefulWidget {
  final String title;
  final String hintText;

  const FacilitySearchScreen({
    super.key,
    this.title = 'Select Hospital',
    this.hintText = 'Search for a hospital or clinic…',
  });

  @override
  State<FacilitySearchScreen> createState() => _FacilitySearchScreenState();
}

class _FacilitySearchScreenState extends State<FacilitySearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Facility> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _searched = false;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await FacilityService.instance.search(query: query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searched = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(Facility facility) => Navigator.pop(context, facility);

  IconData _iconFor(String facilityType) {
    switch (facilityType) {
      case 'PHARMACY':
        return Icons.local_pharmacy_rounded;
      case 'HEALTH_CENTER':
      case 'DISPENSARY':
        return Icons.health_and_safety_rounded;
      case 'CLINIC':
        return Icons.medical_services_rounded;
      case 'HOSPITAL':
      default:
        return Icons.local_hospital_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _cTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixIcon: const Icon(Icons.search, color: _cTeal),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cTeal, width: 2)),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!,
                  style: const TextStyle(color: _cError, fontSize: 12.5)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _cTeal))
                : !_searched
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Start typing to search hospitals, clinics and pharmacies near you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _cMuted, fontSize: 13),
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Text('No facilities found.',
                                style: TextStyle(color: _cMuted, fontSize: 13)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: _cBorder),
                            itemBuilder: (context, i) {
                              final f = _results[i];
                              return ListTile(
                                leading: Icon(_iconFor(f.facilityType), color: _cTeal),
                                title: Text(f.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _cTealDeep)),
                                subtitle: Text(
                                  f.locationLabel.isEmpty
                                      ? f.facilityTypeDisplay
                                      : '${f.locationLabel} · ${f.facilityTypeDisplay}',
                                  style: const TextStyle(fontSize: 12, color: _cMuted),
                                ),
                                onTap: () => _select(f),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
