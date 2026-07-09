import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:patient_app/core/config/social_auth_config.dart';
import 'package:patient_app/core/services/auth_service.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/screens/dashboard/homepage.dart';
import 'package:patient_app/models/auth_session.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: SocialAuthConfig.googleServerClientId.isEmpty
        ? null
        : SocialAuthConfig.googleServerClientId,
  );

  static const Color blue = Color(0xFF2F8FEF);
  static const Color blueDark = Color(0xFF1E63A7);
  static const Color greenDark = Color(0xFF4FA213);
  static const Color ink = Color(0xFF0E2A3D);
  static const Color muted = Color(0xFF668090);
  static const Color border = Color(0xFFD8E8F2);
  static const Color field = Color(0xFFF6FBFE);
  static const Color bg = Color(0xFFF2FAF6);

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    final session = await AuthSession.load();
    final token = await TripApiService.instance.getToken();
    if (session.isLoggedIn && token != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(session: session)),
      );
    } else if (session.isLoggedIn && token == null) {
      // Stale offline session with no JWT — clear it so the login form shows
      await AuthSession.clear();
    }
  }

  void _goToForgotPassword() {
    Navigator.pushNamed(context, '/reset-password');
  }

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final session = await AuthService().loginUser(
        email: emailController.text,
        password: passwordController.text,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(session: session)),
        );
      }
    } on EmailNotVerifiedException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            action: SnackBarAction(
              label: 'Verify now',
              onPressed: () => Navigator.pushNamed(context, '/verify-email', arguments: e.email),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (!SocialAuthConfig.googleConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google sign-in isn't configured yet.")),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return; // user cancelled
      final idToken = (await account.authentication).idToken;
      if (idToken == null) {
        throw Exception('Google did not return an identity token.');
      }
      final session = await AuthService().loginWithGoogle(idToken: idToken);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(session: session)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() => _isLoading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: SocialAuthConfig.appleWebFlowConfigured
            ? WebAuthenticationOptions(
                clientId: SocialAuthConfig.appleServiceId,
                redirectUri: Uri.parse(SocialAuthConfig.appleRedirectUri),
              )
            : null,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Apple did not return an identity token.');
      }
      final nameParts = [credential.givenName, credential.familyName]
          .whereType<String>()
          .where((s) => s.isNotEmpty);
      final fullName = nameParts.isEmpty ? null : nameParts.join(' ');
      final session = await AuthService().loginWithApple(
        idToken: idToken,
        fullName: fullName,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(session: session)),
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple sign-in failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: Offset(0, 8),
                      color: Color.fromRGBO(47, 143, 239, 0.12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/tiba-safari-logo.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7DF),
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: const Icon(
                            Icons.medical_services,
                            size: 60,
                            color: greenDark,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7DF),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFFCDEDB5)),
                      ),
                      child: const Text(
                        'Patient Access',
                        style: TextStyle(color: greenDark, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Login to your account',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your email to login to this app',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 22),
                    
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        prefixIcon: const Icon(Icons.alternate_email, color: blue),
                        filled: true,
                        fillColor: field,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: blue),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: muted, size: 20),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: field,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 2)),
                      ),
                    ),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _goToForgotPassword,
                        child: const Text('Forgot password?', style: TextStyle(color: blueDark, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Continue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    
                    const SizedBox(height: 22),
                    const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or')), Expanded(child: Divider())]),
                    const SizedBox(height: 18),
                    
                    _socialButton(
                      imagePath: 'assets/images/google_logo.png',
                      text: 'Continue with Google',
                      onTap: _isLoading ? null : _handleGoogleLogin,
                    ),
                    const SizedBox(height: 10),
                    _socialButton(
                      imagePath: 'assets/images/apple_logo.png',
                      text: 'Continue with Apple',
                      onTap: _isLoading ? null : _handleAppleLogin,
                    ),
                    const SizedBox(height: 18),
                    
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(color: muted, fontSize: 11),
                        children: [
                          TextSpan(text: 'By clicking continue, you agree to our '),
                          TextSpan(text: 'Terms of Service', style: TextStyle(color: blueDark, fontWeight: FontWeight.bold)),
                          TextSpan(text: ' and '),
                          TextSpan(text: 'Privacy Policy', style: TextStyle(color: blueDark, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("If you don't have an account, "),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text("SIGN UP", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton({required String imagePath, required String text, VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          backgroundColor: const Color(0xFFF8FCFF),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 22, height: 22, errorBuilder: (context, error, stackTrace) => Icon(text.contains('Google') ? Icons.g_mobiledata : Icons.apple, size: 22)),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
