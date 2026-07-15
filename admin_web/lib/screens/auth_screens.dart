import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/app_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isSubmitting = false;
  bool _rememberDevice = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.post('/auth/login/', {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      final access = data['access'] as String?;
      final refresh = data['refresh'] as String?;
      if (access == null || access.isEmpty) {
        throw ApiException('No access token returned by server.', 200);
      }

      AuthStorage.saveTokens(
        access: access,
        refresh: refresh ?? '',
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/admin');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to connect to server. '
          'Check that the backend is running and the API URL is correct.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Admin Login',
      subtitle: 'Sign in to manage bookings, dispatch, billing, and reports.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthTextField(
              label: 'Email address',
              hint: 'admin@tibasafari.co.tz',
              controller: _emailController,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            _AuthPasswordField(
              label: 'Password',
              hint: 'Enter your password',
              controller: _passwordController,
              visible: _showPassword,
              onToggle: () => setState(() => _showPassword = !_showPassword),
              validator: _validatePassword,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _rememberDevice,
                  activeColor: AppTheme.primary,
                  onChanged: (value) {
                    setState(() => _rememberDevice = value ?? false);
                  },
                ),
                const Expanded(
                  child: Text(
                    'Remember this device',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset will be available soon.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _AuthErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 20),
            _AuthButton(
              label: 'Sign in',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 18),
            _AuthPrompt(
              text: 'Need an admin account?',
              action: 'Create account',
              onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _acceptedPolicy = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the admin access policy to continue.'),
          backgroundColor: Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ApiService.post('/accounts/signup/', {
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'password': _passwordController.text,
        'confirm_password': _confirmPasswordController.text,
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Account request submitted'),
          content: const Text(
            'Your admin account request has been captured for approval. Sign in after your access is activated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Go to login'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Unable to connect to server. '
            'Check that the backend is running and the API URL is correct.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Create Admin Account',
      subtitle: 'Request access for operations, finance, or management teams.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthTextField(
              label: 'Full name *',
              hint: 'Enter full name',
              controller: _nameController,
              icon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Enter full name';
                if (name.split(RegExp(r'\s+')).length < 2) {
                  return 'Enter first and last name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _AuthTextField(
              label: 'Email address *',
              hint: 'name@tibasafari.co.tz',
              controller: _emailController,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            _AuthTextField(
              label: 'Phone number *',
              hint: '+255 712 345 678',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                if (digits.isEmpty) return 'Enter phone number';
                if (digits.length < 9) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _AuthTextField(
              label: 'Admin role *',
              hint: 'Operations manager',
              controller: _roleController,
              icon: Icons.admin_panel_settings_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) return 'Enter admin role';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _AuthPasswordField(
              label: 'Password *',
              hint: 'Create a password',
              controller: _passwordController,
              visible: _showPassword,
              onToggle: () => setState(() => _showPassword = !_showPassword),
              validator: _validateNewPassword,
            ),
            const SizedBox(height: 6),
            const Text(
              'Must be at least 8 characters, with 1 uppercase letter and 1 number.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            _AuthPasswordField(
              label: 'Confirm password *',
              hint: 'Re-enter password',
              controller: _confirmPasswordController,
              visible: _showConfirmPassword,
              onToggle: () {
                setState(() => _showConfirmPassword = !_showConfirmPassword);
              },
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _PolicyToggle(
              value: _acceptedPolicy,
              onChanged: (value) => setState(() => _acceptedPolicy = value),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _AuthErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 24),
            _AuthButton(
              label: 'Submit request',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 18),
            _AuthPrompt(
              text: 'Already have access?',
              action: 'Sign in',
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AuthHeader(title: title, subtitle: subtitle),
                        const SizedBox(height: 28),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AuthHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/tiba-safari-logo.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.local_hospital_outlined,
              color: AppTheme.primaryDark,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Tiba Safari',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _AuthTextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }
}

class _AuthPasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool visible;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _AuthPasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.visible,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              onPressed: onToggle,
              tooltip: visible ? 'Hide password' : 'Show password',
              icon: Icon(
                visible ? Icons.visibility_off_outlined : Icons.visibility,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PolicyToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PolicyToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              activeColor: AppTheme.primary,
              onChanged: (checked) => onChanged(checked ?? false),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'I confirm this account is for authorized Tiba Safari administration and accept responsibility for protecting patient and trip data.',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _AuthButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _AuthPrompt extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;

  const _AuthPrompt({
    required this.text,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$text ',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  final String message;
  const _AuthErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFB91C1C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter email address';
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter password';
  if (value.length < 6) return 'Password must be at least 6 characters';
  return null;
}

/// Stricter rule for new-account creation only — kept separate from
/// [_validatePassword] (used at login) so existing admins whose passwords
/// predate this rule aren't locked out.
String? _validateNewPassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter password';
  if (value.length < 8) return 'Password must be at least 8 characters';
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must include at least 1 uppercase letter';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Password must include at least 1 number';
  }
  return null;
}
