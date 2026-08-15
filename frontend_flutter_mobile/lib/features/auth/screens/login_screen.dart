import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/l10n_extensions.dart';

/// Mobile equivalent of `frontend-flutter-pos/lib/features/auth/screens/
/// login_screen.dart`. NOT a shrunk copy of the desktop two-panel (58/42
/// split) branding layout — that layout assumes a wide viewport most phones
/// don't have. This is a single-column, centered form: logo, welcome text,
/// email/password fields, error banner, login button. The desktop file's
/// purely-decorative marketing content (feature pills, background image,
/// gradient panel, footer copyright, and the non-functional "Remember me" /
/// "Forgot password" / "Register" stubs — all `onTap: () {}` no-ops in
/// source) is intentionally dropped; every functional element (validation
/// messages, error handling, the login call itself) is unchanged. See
/// DAY_04.md sections 7–10 for the full mapping.
///
/// Reads `Theme.of(context).colorScheme.primary` for its primary-action
/// elements (logo mark, focused field borders, login button) exactly like
/// the current source screen does post main-color-configurability work —
/// never a hardcoded brand color. See DAY_04.md "Problems Found".
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController =
      TextEditingController(text: 'owner@kaknnea.local');
  final TextEditingController _passwordController =
      TextEditingController(text: 'Password123!');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// REUSE EXISTING FUNCTION shape from `[OLD/SOURCE] LoginScreen._login()` —
  /// identical body: validate → `authProvider.notifier.login()` → navigate
  /// on success → SnackBar on failure. Only the destination route differs
  /// (`/` here vs `/pos` in source) because the mobile app's post-login home
  /// route is Day 5 scope, not yet named — see DAY_04.md section 8.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.authLoginFailed}: $error'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(final BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: PosTheme.backgroundPageOf(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: PosTheme.spacingXl, vertical: PosTheme.spacingXxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius:
                              BorderRadius.circular(PosTheme.radiusLarge),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'K',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: PosTheme.spacingXl),
                    Text(
                      l10n.loginScreenWelcomeBack,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: PosTheme.spacingSm),
                    Text(
                      l10n.loginScreenSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: PosTheme.textSecondaryOf(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: PosTheme.spacingXxl),
                    Text(l10n.formEmail,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: PosTheme.spacingSm),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        hintText: l10n.loginScreenEnterUsernameHint,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: PosTheme.spacingLg,
                            vertical: PosTheme.spacingLg),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PosTheme.radiusLarge),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? l10n.loginScreenEmailRequired
                          : null,
                    ),
                    const SizedBox(height: PosTheme.spacingLg),
                    Text(l10n.authPassword,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: PosTheme.spacingSm),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        hintText: l10n.loginScreenEnterPasswordHint,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: PosTheme.spacingLg,
                            vertical: PosTheme.spacingLg),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PosTheme.radiusLarge),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? l10n.loginScreenPasswordRequired
                          : (v.length < 6
                              ? l10n.loginScreenPasswordMinLength
                              : null),
                    ),
                    const SizedBox(height: PosTheme.spacingXl),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(PosTheme.radiusLarge),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                l10n.authLogin.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
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
}
