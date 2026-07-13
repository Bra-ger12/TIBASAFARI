import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class VehicleFormScreen extends StatefulWidget {
  final NavState nav;
  final bool isEdit;
  const VehicleFormScreen(
      {super.key, required this.nav, required this.isEdit});
  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _model = TextEditingController();
  final _make = TextEditingController();
  final _year = TextEditingController(text: DateTime.now().year.toString());
  final _capacity = TextEditingController(text: '4');
  String _type = 'ambulance';
  String _status = 'available';
  bool _loading = false;
  bool _saving = false;
  String? _editId;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    setState(() => _loading = true);
    try {
      final res =
          await ApiService.get('/operations/vehicles/${widget.nav.selectedVehicleId}/');
      final v = Vehicle.fromJson(res);
      _editId = v.id;
      _plate.text = v.plate;
      _model.text = v.model;
      _make.text = v.make;
      _year.text = v.year == 0 ? _year.text : v.year.toString();
      _capacity.text = v.capacity.toString();
      _type = v.type;
      _status = v.status;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'registration_number': _plate.text,
        'model': _model.text,
        'make': _make.text,
        'year': int.tryParse(_year.text) ?? DateTime.now().year,
        'capacity': int.tryParse(_capacity.text) ?? 4,
        'has_wheelchair_access': _type == 'wheelchair-van',
        'status': _status,
      };
      if (widget.isEdit && _editId != null) {
        await ApiService.patch('/operations/vehicles/$_editId/', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vehicle updated successfully.')));
        }
      } else {
        await ApiService.post('/operations/vehicles/', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vehicle added to fleet.')));
        }
      }
      if (mounted) widget.nav.navigate(ViewKey.vehiclesList);
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
    _plate.dispose();
    _model.dispose();
    _make.dispose();
    _year.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingRows();
    return PageScaffold(
      title: widget.isEdit ? 'Edit Vehicle' : 'Add Vehicle',
      description: widget.isEdit
          ? 'Update vehicle details in the fleet inventory.'
          : 'Register a new vehicle in the fleet.',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => widget.nav.navigate(ViewKey.vehiclesList),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: SectionCard(
              title: 'Vehicle Information',
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
                        TextFormField(
                          controller: _plate,
                          decoration: const InputDecoration(
                              labelText: 'Plate Number *'),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        TextFormField(
                          controller: _model,
                          decoration:
                              const InputDecoration(labelText: 'Model *'),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        TextFormField(
                          controller: _make,
                          decoration:
                              const InputDecoration(labelText: 'Make *'),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        TextFormField(
                          controller: _year,
                          decoration:
                              const InputDecoration(labelText: 'Year *'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final year = int.tryParse(v ?? '');
                            if (year == null) return 'Required';
                            if (year < 1990) return 'Year is too old';
                            return null;
                          },
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
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
                        DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                              labelText: 'Vehicle Type'),
                          items: const [
                            DropdownMenuItem(
                                value: 'ambulance', child: Text('Ambulance')),
                            DropdownMenuItem(
                                value: 'wheelchair-van',
                                child: Text('Wheelchair Van')),
                            DropdownMenuItem(value: 'van', child: Text('Van')),
                            DropdownMenuItem(value: 'car', child: Text('Car')),
                            DropdownMenuItem(
                                value: 'minibus', child: Text('Minibus')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _type = v);
                          },
                        ),
                        TextFormField(
                          controller: _capacity,
                          decoration: const InputDecoration(
                              labelText: 'Seating Capacity'),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration:
                        const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'available', child: Text('Available')),
                      DropdownMenuItem(
                          value: 'in_service', child: Text('In Service')),
                      DropdownMenuItem(
                          value: 'maintenance', child: Text('Maintenance')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => widget.nav.navigate(ViewKey.vehiclesList),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save, size: 16),
                        label: Text(widget.isEdit
                            ? 'Save Changes'
                            : 'Add Vehicle'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
