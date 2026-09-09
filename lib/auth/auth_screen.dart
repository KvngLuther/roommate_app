import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widget.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = true;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;
  bool _obscure = true;
  bool _awaitingVerification = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Email format validation ──────────────────────────────────────
  /// Returns true only for addresses like user@domain.tld.
  /// Rejects bare names, missing domains, and domains without a dot.
  bool _isValidEmail(String email) {
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email);
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    // Client-side format check — catches obvious mistakes before hitting Firebase
    if (!_isValidEmail(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final state = context.read<AppState>();
      if (_isSignUp) {
        await state.signUp(email, password);
        // After sign-up, show the verification pending screen.
        if (mounted) {
          setState(() {
            _awaitingVerification = true;
            _info = 'Verification email sent to $email';
          });
        }
      } else {
        await state.signIn(email, password);
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await context.read<AppState>().sendPasswordReset(email);
      if (mounted) {
        setState(() => _info = 'Reset link sent to $email');
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (raw.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (raw.contains('network-request-failed')) {
      return 'Network error – check your connection.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    }
    if (raw.contains('user-disabled')) return 'This account has been disabled.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingVerification) {
      return _VerificationPendingScreen(
        email: _emailCtrl.text.trim(),
        onResend: () async {
          setState(() { _loading = true; _info = null; _error = null; });
          try {
            await context.read<AppState>().sendEmailVerification();
            if (mounted) setState(() => _info = 'Verification email resent.');
          } on Exception catch (e) {
            if (mounted) setState(() => _error = _friendlyError(e.toString()));
          } finally {
            if (mounted) setState(() => _loading = false);
          }
        },
        onCheckVerified: () async {
          setState(() => _loading = true);
          final verified = await context.read<AppState>().reloadAndCheckVerified();
          if (mounted) {
            if (!verified) {
              setState(() {
                _loading = false;
                _error = 'Email not yet verified. Check your inbox.';
              });
            }
            // If verified, AppState notifies listeners and the router
            // automatically navigates away — nothing extra needed here.
          }
        },
        onBack: () => setState(() {
          _awaitingVerification = false;
          _isSignUp = false;
          _error = null;
          _info = null;
        }),
        isLoading: _loading,
        error: _error,
        info: _info,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Logo ──
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Center(
                  child: Text('🏠', style: TextStyle(fontSize: 32)),
                ),
              ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),

              const SizedBox(height: 28),

              // ── Heading ──
              Text(
                _isSignUp ? 'Create account' : 'Welcome back',
                style: Theme.of(context).textTheme.displaySmall,
              ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 6),

              Text(
                _isSignUp
                    ? 'Set up or join your shared home'
                    : 'Sign in to get back to your household',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 120.ms),

              const SizedBox(height: 36),

              // ── Email ──
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                onChanged: (_) => setState(() => _error = null),
              ).animate().fadeIn(delay: 160.ms),

              const SizedBox(height: 12),

              // ── Password ──
              TextField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
              ).animate().fadeIn(delay: 200.ms),

              // ── Forgot password ──
              if (!_isSignUp)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ).animate().fadeIn(delay: 220.ms),

              // ── Error / Info ──
              if (_error != null) ...[
                const SizedBox(height: 12),
                _StatusBanner(
                  message: _error!,
                  isError: true,
                ).animate().fadeIn().shakeX(hz: 3, amount: 4),
              ],

              if (_info != null) ...[
                const SizedBox(height: 12),
                _StatusBanner(
                  message: _info!,
                  isError: false,
                ).animate().fadeIn(),
              ],

              const SizedBox(height: 28),

              // ── Submit ──
              LoadingButton(
                isLoading: _loading,
                onPressed: _submit,
                label: _isSignUp ? 'Create Account' : 'Sign In',
              ).animate().fadeIn(delay: 280.ms),

              const SizedBox(height: 20),

              // ── Toggle ──
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _error = null;
                    _info = null;
                  }),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: _isSignUp
                              ? 'Already have an account?  '
                              : "Don't have an account?  ",
                        ),
                        TextSpan(
                          text: _isSignUp ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Verification Pending Screen ───────────────────────────────────
class _VerificationPendingScreen extends StatelessWidget {
  final String email;
  final VoidCallback onResend;
  final VoidCallback onCheckVerified;
  final VoidCallback onBack;
  final bool isLoading;
  final String? error;
  final String? info;

  const _VerificationPendingScreen({
    required this.email,
    required this.onResend,
    required this.onCheckVerified,
    required this.onBack,
    required this.isLoading,
    this.error,
    this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Center(
                  child: Text('📧', style: TextStyle(fontSize: 32)),
                ),
              ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),

              const SizedBox(height: 28),

              Text(
                'Verify your email',
                style: Theme.of(context).textTheme.displaySmall,
              ).animate().fadeIn(delay: 80.ms),

              const SizedBox(height: 8),

              Text(
                'We sent a verification link to:',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 4),

              Text(
                email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ).animate().fadeIn(delay: 120.ms),

              const SizedBox(height: 8),

              Text(
                'Open the email and tap the link, then come back and press "I\'ve verified" below.',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 140.ms),

              if (error != null) ...[
                const SizedBox(height: 16),
                _StatusBanner(message: error!, isError: true)
                    .animate()
                    .fadeIn()
                    .shakeX(hz: 3, amount: 4),
              ],

              if (info != null) ...[
                const SizedBox(height: 16),
                _StatusBanner(message: info!, isError: false).animate().fadeIn(),
              ],

              const Spacer(),

              // I've verified button
              LoadingButton(
                isLoading: isLoading,
                onPressed: onCheckVerified,
                label: "I've verified my email",
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 12),

              // Resend
              Center(
                child: TextButton(
                  onPressed: isLoading ? null : onResend,
                  child: const Text("Resend verification email"),
                ),
              ).animate().fadeIn(delay: 220.ms),

              // Back to sign in
              Center(
                child: TextButton(
                  onPressed: onBack,
                  child: const Text("Back to Sign In"),
                ),
              ).animate().fadeIn(delay: 240.ms),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.danger : AppTheme.success;
    final bg = isError ? AppTheme.dangerSurface : AppTheme.successSurface;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}