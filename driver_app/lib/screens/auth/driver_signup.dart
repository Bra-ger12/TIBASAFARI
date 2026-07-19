import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../routes/app_routes.dart';
import '../../services/driver_service.dart';

class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedTerms = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the driver terms to continue'),
          backgroundColor: cError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await DriverService.instance.signupDriver(
        fullName: _fullNameController.text,
        phoneNumber: '+255 ${_phoneController.text.trim()}',
        email: email,
        licenseNumber: _licenseController.text,
        password: password,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;
      try {
        // Signup activates the account immediately (no approval gate), so
        // sign the driver straight in rather than sending them back to the
        // login screen to re-enter the password they just chose.
        final session = await DriverService.instance.login(
          email: email,
          password: password,
        );
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.driverHome,
          (route) => false,
          arguments: session,
        );
      } catch (_) {
        // Account was created fine; only the automatic sign-in failed
        // (e.g. a transient network hiccup) — fall back to manual login.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Please login with your new password.',
            ),
            backgroundColor: cTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signup failed: ${_errorText(e)}'),
          backgroundColor: cError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please create a password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must include at least 1 uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must include at least 1 number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 18),
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildTextField(
                        label: 'Full name *',
                        hint: 'Enter your full name',
                        controller: _fullNameController,
                        icon: Icons.badge_outlined,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Please enter your name';
                          if (trimmed.split(RegExp(r'\s+')).length < 2) {
                            return 'Enter first and last name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Phone number *',
                        hint: '712 345 678',
                        controller: _phoneController,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        prefixText: '+255 ',
                        validator: (value) {
                          final digits =
                              value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                          if (digits.isEmpty) {
                            return 'Please enter phone number';
                          }
                          if (digits.length < 9) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Email address *',
                        hint: 'driver@example.com',
                        controller: _emailController,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Please enter email';
                          final emailPattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                          if (!emailPattern.hasMatch(trimmed)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Driving license number *',
                        hint: 'Enter license number',
                        controller: _licenseController,
                        icon: Icons.credit_card_outlined,
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if ((value?.trim() ?? '').length < 5) {
                            return 'Enter a valid license number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        label: 'Password *',
                        hint: 'Create a password',
                        controller: _passwordController,
                        isVisible: _isPasswordVisible,
                        onToggle: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Must be at least 8 characters, with 1 uppercase letter and 1 number.',
                        style: TextStyle(fontSize: 11.5, color: cMuted),
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        label: 'Confirm password *',
                        hint: 'Re-enter password',
                        controller: _confirmPasswordController,
                        isVisible: _isConfirmPasswordVisible,
                        onToggle: () => setState(
                          () => _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible,
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildTermsToggle(),
                      const SizedBox(height: 24),
                      _buildSignupButton(),
                      const SizedBox(height: 18),
                      _buildSigninPrompt(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: cTealDeep),
          tooltip: 'Back',
        ),
        const SizedBox(width: 4),
        const Text(
          'Driver signup',
          style: TextStyle(
            color: cTealDeep,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cTeal.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/tiba-safari-logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: cTeal,
                  size: 34,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Create Driver Account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cTealDeep,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Submit your driver details for TibaSafari verification',
          textAlign: TextAlign.center,
          style: TextStyle(color: cMuted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: cTealDeep),
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
            prefixText: prefixText,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: cTealDeep),
          decoration: _inputDecoration(
            hint: hint,
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                isVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: cMutedLight,
                size: 20,
              ),
              tooltip: isVisible ? 'Hide password' : 'Show password',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: cTealDeep,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: cMutedLight, fontSize: 14),
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: cTealDeep, fontSize: 14),
      prefixIcon: Icon(icon, color: cMutedLight, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cTeal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cError, width: 1.5),
      ),
    );
  }

  Widget _buildTermsToggle() {
    return InkWell(
      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cTealLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _acceptedTerms,
              onChanged: (value) =>
                  setState(() => _acceptedTerms = value ?? false),
              activeColor: cTeal,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'I confirm that my license and vehicle information is accurate and agree to follow TibaSafari driver safety standards.',
                style: TextStyle(color: cTealDeep, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: cTeal,
          disabledBackgroundColor: cTeal.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submit Signup Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildSigninPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Flexible(
          child: Text(
            'Already approved? ',
            style: TextStyle(color: cMuted, fontSize: 13),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (route) => false,
          ),
          child: const Text(
            'Login',
            style: TextStyle(
              color: cTeal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
