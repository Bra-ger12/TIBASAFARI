import 'dart:async';

import 'package:flutter/material.dart';
import 'package:patient_app/core/services/auth_service.dart';
import 'package:patient_app/core/theme/colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isVerifying = false;
  bool _isResending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isVerifying = true);
    try {
      await AuthService().verifyEmail(email: widget.email, code: _codeController.text.trim());
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified — please sign in'),
          backgroundColor: cGreenDark,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: cError,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await AuthService().resendVerification(email: widget.email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent'), backgroundColor: cGreenDark),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: cError,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cBorder),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: Offset(0, 8),
                      color: Color.fromRGBO(47, 143, 239, 0.12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(color: Color(0xFFEAF7DF), shape: BoxShape.circle),
                        child: const Icon(Icons.mark_email_read_outlined, color: cGreenDark, size: 36),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Verify your email',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cInk),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the 6-digit code sent to\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: cMuted, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8, color: cInk),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          filled: true,
                          fillColor: cField,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cBlue, width: 2)),
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.length != 6 || int.tryParse(s) == null) {
                            return 'Enter the 6-digit code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: cBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: _isVerifying ? null : _verify,
                          child: _isVerifying
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Verify', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: (_isResending || _cooldownSeconds > 0) ? null : _resend,
                        child: Text(
                          _cooldownSeconds > 0 ? 'Resend code (${_cooldownSeconds}s)' : 'Resend code',
                          style: const TextStyle(color: cBlueDark, fontWeight: FontWeight.w600),
                        ),
                      ),
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
}
