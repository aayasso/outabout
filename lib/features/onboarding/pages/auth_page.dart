import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/behavioral_event_service.dart';
import '../../../services/notification_service.dart';
import '../widgets/onboarding_button.dart';

class AuthPage extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const AuthPage({super.key, required this.onNext});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = true;
  bool _isLoading = false;
  bool _showMagicLink = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final AuthResult result;

    if (_showMagicLink) {
      result = await authService.sendMagicLink(_emailController.text.trim());
      if (result.success) {
        setState(() {
          _isLoading = false;
          _successMessage = 'Check your email for a sign-in link!';
        });
        return;
      }
    } else if (_isSignUp) {
      result = await authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      result = await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    setState(() => _isLoading = false);

    if (result.success) {
      OutAboutHaptics.onConditionMatch();
      ref.read(behavioralEventServiceProvider).log('auth_completed');
      final userId =
          ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId != null) {
        ref.read(notificationServiceProvider).setUserTag(userId);
      }
      widget.onNext();
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  Future<void> _handleSkip() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final authService = ref.read(authServiceProvider);
    final result = await authService.signInAnonymously();
    setState(() => _isLoading = false);

    if (result.success) {
      ref.read(behavioralEventServiceProvider).log('auth_skipped');
      final userId =
          ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId != null) {
        ref.read(notificationServiceProvider).setUserTag(userId);
      }
      widget.onNext();
    } else {
      setState(() => _errorMessage =
          'Unable to continue as guest. Please try again or create an account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OutAboutSpacing.xl),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: OutAboutSpacing.xxxl),
                Text(
                  _isSignUp ? 'Create your account' : 'Welcome back',
                  style: OutAboutTypography.displayLarge(colors),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: OutAboutSpacing.sm),
                Text(
                  _isSignUp
                      ? 'Sign up to save your activities and get notified.'
                      : 'Sign in to access your activities.',
                  style: OutAboutTypography.bodyLarge(colors),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: OutAboutSpacing.xl),

                // Toggle chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ToggleChip(
                      label: 'Sign Up',
                      isSelected: _isSignUp && !_showMagicLink,
                      colors: colors,
                      onTap: () => setState(() {
                        _isSignUp = true;
                        _showMagicLink = false;
                        _errorMessage = null;
                        _successMessage = null;
                      }),
                    ),
                    const SizedBox(width: OutAboutSpacing.sm),
                    _ToggleChip(
                      label: 'Sign In',
                      isSelected: !_isSignUp && !_showMagicLink,
                      colors: colors,
                      onTap: () => setState(() {
                        _isSignUp = false;
                        _showMagicLink = false;
                        _errorMessage = null;
                        _successMessage = null;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: OutAboutSpacing.lg),

                // Email field
                Semantics(
                  label: 'Email address',
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(OutAboutRadius.buttons),
                      ),
                    ),
                  ),
                ),

                // Password field (hidden in magic link mode)
                if (!_showMagicLink) ...[
                  const SizedBox(height: OutAboutSpacing.md),
                  Semantics(
                    label: 'Password',
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(OutAboutRadius.buttons),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: OutAboutSpacing.md),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(OutAboutSpacing.md),
                    decoration: BoxDecoration(
                      color: OutAboutColors.errorColor.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(OutAboutRadius.buttons),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: OutAboutTypography.bodyMedium(colors).copyWith(
                        color: OutAboutColors.errorColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Success message (magic link sent)
                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(OutAboutSpacing.md),
                    decoration: BoxDecoration(
                      color: OutAboutColors.success.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(OutAboutRadius.buttons),
                    ),
                    child: Text(
                      _successMessage!,
                      style: OutAboutTypography.bodyMedium(colors).copyWith(
                        color: OutAboutColors.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: OutAboutSpacing.lg),

                // Submit button
                OnboardingButton(
                  label: _showMagicLink
                      ? 'Send Magic Link'
                      : (_isSignUp ? 'Sign Up' : 'Sign In'),
                  onPressed: _isLoading ? null : _handleSubmit,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: OutAboutSpacing.md),

                // Magic link toggle
                if (!_showMagicLink)
                  TextButton(
                    onPressed: () => setState(() {
                      _showMagicLink = true;
                      _errorMessage = null;
                      _successMessage = null;
                    }),
                    child: Text(
                      'Use Magic Link Instead',
                      style: OutAboutTypography.labelLarge(colors).copyWith(
                        color: colors.primaryInteractive,
                      ),
                    ),
                  ),

                if (_showMagicLink)
                  TextButton(
                    onPressed: () => setState(() {
                      _showMagicLink = false;
                      _errorMessage = null;
                      _successMessage = null;
                    }),
                    child: Text(
                      'Use Password Instead',
                      style: OutAboutTypography.labelLarge(colors).copyWith(
                        color: colors.primaryInteractive,
                      ),
                    ),
                  ),

                const SizedBox(height: OutAboutSpacing.sm),

                // Skip
                TextButton(
                  onPressed: _isLoading ? null : _handleSkip,
                  child: Text(
                    'Skip for Now',
                    style: OutAboutTypography.labelMedium(colors).copyWith(
                      color: colors.text.withOpacity(0.6),
                    ),
                  ),
                ),

                const SizedBox(height: OutAboutSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    ).animateSafely(context)
        .fadeIn(duration: OutAboutAnimations.standardDuration)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: OutAboutAnimations.standardDuration,
          curve: Curves.easeOutCubic,
        );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final WeatherThemeColors colors;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: OutAboutAnimations.standardDuration,
        padding: const EdgeInsets.symmetric(
          horizontal: OutAboutSpacing.lg,
          vertical: OutAboutSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(OutAboutRadius.full),
          border: Border.all(
            color: isSelected ? colors.primary : colors.text.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: OutAboutTypography.labelLarge(colors).copyWith(
            color: isSelected ? colors.onPrimary : colors.text,
          ),
        ),
      ),
    );
  }
}
