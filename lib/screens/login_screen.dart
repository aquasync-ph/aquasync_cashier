import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'components/top_alert.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  late AnimationController _entranceController;
  late Animation<double> _bodyFade;
  late Animation<Offset> _bodySlide;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _bodyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 0.8, curve: Curves.easeIn)),
    );

    _bodySlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 0.9, curve: Curves.fastOutSlowIn)),
    );

    _entranceController.forward();

    // Ensure that if user already has an active session (e.g. visiting /login via browser history/back),
    // they are automatically restored & redirected to dashboard instead of being logged out.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          final isAuthenticated = await context.read<AppState>().restoreSession();
          if (mounted && isAuthenticated) {
            Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
          }
        }
      } catch (e) {
        debugPrint('LoginScreen session check note: $e');
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _entranceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _shake() {
    _shakeController.forward(from: 0);
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      _shake();
      return;
    }

    HapticFeedback.mediumImpact();
    final appState = context.read<AppState>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await appState.login(email, password);
      if (!mounted) return;

      _showSuccessDialog(appState.cashierName ?? 'Cashier');
    } catch (e) {
      if (!mounted) return;
      _shake();
      TopAlert.show(
        context,
        e.toString().replaceAll('Exception: ', ''),
        type: AlertType.error,
        title: 'Login Failed',
      );
    }
  }

  void _showSuccessDialog(String name) {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success.withValues(alpha: 0.25),
                          AppColors.success.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Login Successful!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDarkNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.cyanGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.electricCyan.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.white, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Welcome, $name!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Directing you to your POS Terminal...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.grayText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.electricCyan),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/dashboard',
          (Route<dynamic> route) => false, // Clears the entire stack
        );
      }
    });
  }

  void _showForgotPasswordDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ForgotPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFDFF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Curved Dark Arc Header (Slate Style)
            ClipPath(
              clipper: HeaderArcClipper(),
              child: AnimatedBuilder(
                animation: _entranceController,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    height: isDesktop ? 320 : 280,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF01082D), Color(0xFF041D56), Color(0xFF0F2573)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Hero(
                                  tag: 'aquasync_header_logo',
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: AppGradients.electric,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.paletteMedium.withValues(alpha: 0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.water_drop_rounded,
                                      size: 32,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Text(
                                  'AQUASYNC',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Welcome back! Log in to continue.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Form Body Section below the Arc
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
                  child: SlideTransition(
                    position: _bodySlide,
                    child: FadeTransition(
                      opacity: _bodyFade,
                      child: AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value * ((DateTime.now().millisecond % 2 == 0) ? 1 : -1), 0),
                            child: child,
                          );
                        },
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDarkNavy,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 28),

                              const Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDarkNavy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'cashier@aquasync.com',
                                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.paletteMedium),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.border, width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.border, width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2),
                                  ),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                              ),
                              const SizedBox(height: 20),

                              const Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDarkNavy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.paletteMedium),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: AppColors.slate,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.border, width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.border, width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2),
                                  ),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Password is required' : null,
                              ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: AppColors.primaryDarkNavy,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Full Width Pill Button
                              SizedBox(
                                height: 56,
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.paletteMidnight,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 6,
                                    shadowColor: AppColors.paletteMidnight.withValues(alpha: 0.35),
                                  ),
                                  child: Consumer<AppState>(
                                    builder: (context, appState, child) {
                                      if (appState.isLoading) {
                                        return const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        );
                                      }
                                      return const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),

                              // Authorized Notice Footer
                              const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified_user_rounded, size: 16, color: AppColors.grayText),
                                    SizedBox(width: 6),
                                    Text(
                                      'Authorized AquaSync Cashier Terminal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.grayText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 45);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 35,
      size.width,
      size.height - 45,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSuccess = false;
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 180);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      if (mounted) {
        setState(() => _isSuccess = true);
        _startCooldownTimer();
      }
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'Error: $e', type: AlertType.error, title: 'Password Reset Failed');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 20,
      shadowColor: AppColors.primaryNavy.withValues(alpha: 0.3),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Icon Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.lightAqua,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.electricCyan.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 42,
                  color: AppColors.electricCyan,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDarkNavy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your cashier email address below and we will send you a secure password reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.grayText,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'cashier@aquasync.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.electricCyan),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                ),
              ),
              const SizedBox(height: 20),

              if (_isSuccess) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Password reset link sent to your email!',
                          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || _secondsRemaining > 0) ? null : _sendResetLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.paletteMidnight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          _secondsRemaining > 0 ? 'RESEND IN ${_secondsRemaining}s' : 'SEND RESET LINK',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.grayText, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
