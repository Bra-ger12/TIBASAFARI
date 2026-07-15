import 'package:flutter/material.dart';
import 'package:patient_app/core/services/auth_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';

class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  static const _stepTitles = ['Personal Info', 'Medical Needs', 'Password'];

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 0;
  bool _agreed = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String _mobilityNeeds = 'NONE';
  bool _oxygenRequired = false;
  bool _medicalEscortRequired = false;
  bool _ivDripRequired = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  GlobalKey<FormState> get _currentFormKey {
    switch (_currentStep) {
      case 0:
        return _step1Key;
      case 1:
        return _step2Key;
      default:
        return _step3Key;
    }
  }

  void _goNext() {
    if (!_currentFormKey.currentState!.validate()) return;
    if (_currentStep < _stepTitles.length - 1) {
      setState(() => _currentStep++);
    } else {
      _createAccount();
    }
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _currentStep--);
    }
  }

  Future<void> _createAccount() async {
    if (!_agreed) {
      _snack('You must agree to the Terms');
      return;
    }

    setState(() => _loading = true);
    final email = _emailController.text.trim();
    try {
      await AuthService().registerPatient(
        fullName: _nameController.text.trim(),
        email: email,
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        emergencyContactName: _contactNameController.text.trim(),
        emergencyContactPhone: _contactPhoneController.text.trim(),
        mobilityNeeds: _mobilityNeeds,
        oxygenRequired: _oxygenRequired,
        medicalEscortRequired: _medicalEscortRequired,
        ivDripRequired: _ivDripRequired,
      );
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
      setState(() => _loading = false);
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushNamedAndRemoveUntil('/verify-email', (route) => false, arguments: email);
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must include at least 1 uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must include at least 1 number';
    }
    return null;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  Widget _stepIndicator() {
    return Row(
      children: List.generate(_stepTitles.length, (i) {
        final isActive = i <= _currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == _stepTitles.length - 1 ? 0 : 6),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _step1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.trim().split(' ').length < 2) {
                return 'Enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(prefixText: '+255 ', labelText: 'Phone Number *', border: OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Phone number is required';
              if (value.replaceAll(' ', '').length < 9) return 'Enter valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email Address *', border: OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email address is required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Enter valid email';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: AppFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }

  Widget _step2() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Mobility Assistance'),
          RadioGroup<String>(
            groupValue: _mobilityNeeds,
            onChanged: (value) => setState(() => _mobilityNeeds = value!),
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'NONE',
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('None'),
                ),
                RadioListTile<String>(
                  value: 'WHEELCHAIR',
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wheelchair'),
                ),
                RadioListTile<String>(
                  value: 'STRETCHER',
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Stretcher'),
                ),
                RadioListTile<String>(
                  value: 'WALKER_CRUTCHES',
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Walker / Crutches'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          _sectionLabel('Medical Support'),
          CheckboxListTile(
            value: _oxygenRequired,
            onChanged: (value) => setState(() => _oxygenRequired = value ?? false),
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Oxygen support'),
          ),
          CheckboxListTile(
            value: _medicalEscortRequired,
            onChanged: (value) => setState(() => _medicalEscortRequired = value ?? false),
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Medical escort'),
          ),
          CheckboxListTile(
            value: _ivDripRequired,
            onChanged: (value) => setState(() => _ivDripRequired = value ?? false),
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('IV drip required'),
          ),

          const SizedBox(height: 8),
          _sectionLabel('Emergency Contact'),
          TextFormField(
            controller: _contactNameController,
            decoration: const InputDecoration(
              labelText: 'Emergency Contact Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter contact name';
              if (value.trim().length < 3) return 'Name must be at least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Emergency Contact Phone *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined),
              prefixText: '+255 ',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter phone number';
              final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (cleaned.length < 9) return 'Please enter a valid phone number (at least 9 digits)';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _step3() {
    return Form(
      key: _step3Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: _validatePassword,
          ),
          const SizedBox(height: 6),
          Text(
            'Must be at least 8 characters, with 1 uppercase letter and 1 number.',
            style: AppFonts.manrope(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm Password *',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _agreed,
            onChanged: (value) => setState(() => _agreed = value ?? false),
            activeColor: AppColors.primary,
            title: const Text('I agree to the Terms and Privacy Policy'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _currentStepContent() {
    switch (_currentStep) {
      case 0:
        return _step1();
      case 1:
        return _step2();
      default:
        return _step3();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _currentStep == _stepTitles.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Text('Back', style: AppFonts.sora(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_stepTitles[_currentStep], style: AppFonts.sora(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Step ${_currentStep + 1} of ${_stepTitles.length}',
                    style: AppFonts.manrope(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _stepIndicator(),
                  const SizedBox(height: 24),

                  _currentStepContent(),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _goNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                          : Text(
                              isLastStep ? 'CREATE ACCOUNT' : 'NEXT',
                              style: AppFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('Sign In', style: AppFonts.sora(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
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
