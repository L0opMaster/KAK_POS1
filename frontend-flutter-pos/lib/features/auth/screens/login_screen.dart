import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';

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
  // final TextEditingController _terminalID = TextEditingController(text: '1');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text.trim(),
            // terminalId: _terminalID.text.trim(),
          );
      if (mounted) Navigator.of(context).pushReplacementNamed('/pos');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${context.l10n.authLoginFailed}: $error'),
              backgroundColor: PosTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(final BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = context.l10n;

    return Scaffold(
      body: Row(
        children: [
          // ═══ LEFT SIDE — Branding (58%) ═══
          Expanded(
            flex: 58,
            child: Stack(
              children: [
                // Background with gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0f766e).withOpacity(0.92),
                          const Color(0xFF115e59).withOpacity(0.92),
                        ],
                      ),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1556740749-887f6717d7e4?q=80&w=1400',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                // Decorative circles
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  right: -80,
                  bottom: -80,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  top: 80,
                  left: 60,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
                        shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: Container(
                    width: 750,
                    height: 750,
                    decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.white.withOpacity(0.05)),
                        shape: BoxShape.circle),
                  ),
                ),
                // Content
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Badge
                        Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon(Icons.point_of_sale,
                              //     size: 16,
                              //     color: Colors.white.withOpacity(0.9)),
                              // const SizedBox(width: 8),
                              // Text(l10n.loginScreenBadge,
                              //     style: TextStyle(
                              //         fontSize: 14,
                              //         fontWeight: FontWeight.w600,
                              //         color: Colors.white.withOpacity(0.9))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Title
                        // Text(l10n.loginScreenHeadline,
                        //     textAlign: TextAlign.center,
                        //     style: TextStyle(
                        //         fontSize: 56,
                        //         fontWeight: FontWeight.w800,
                        //         color: Colors.white,
                        //         letterSpacing: -0.5,
                        //         height: 1.1)),
                        const SizedBox(height: 20),
                        // Text(l10n.loginScreenDescription,
                        //     textAlign: TextAlign.center,
                        //     style: TextStyle(
                        //         fontSize: 15,
                        //         color: Colors.white.withOpacity(0.85),
                        //         height: 1.8)),
                        // const SizedBox(height: 40),
                        // Feature pills
                        // Wrap(
                        //   spacing: 12,
                        //   runSpacing: 12,
                        //   alignment: WrapAlignment.center,
                        //   children: [
                        //     // _featurePill(Icons.restaurant,
                        //     //     l10n.loginScreenFeatureRestaurant),
                        //     _featurePill(Icons.inventory_2, l10n.navInventory),
                        //     _featurePill(Icons.trending_up, l10n.navReports),
                        //     _featurePill(Icons.store,
                        //         l10n.loginScreenFeatureMultiBranch),
                        //   ],
                        // ),
                      ],
                    ),
                  ),
                ),
                // Footer
                // Positioned(
                //   bottom: 20,
                //   left: 0,
                //   right: 0,
                //   child: Center(
                //     child: Text(l10n.loginScreenCopyright,
                //         style: TextStyle(
                //             fontSize: 12,
                //             color: Colors.white.withOpacity(0.8))),
                //   ),
                // ),
              ],
            ),
          ),

          // ═══ RIGHT SIDE — Login Form (42%) ═══
          Expanded(
            flex: 42,
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  left: -100,
                  top: 100,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                        color: const Color(0xFFfb923c).withOpacity(0.15),
                        shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  right: 80,
                  top: -60,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                        color: const Color(0xFF14b8a6).withOpacity(0.15),
                        shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  right: -90,
                  bottom: -90,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                        color: const Color(0xFFfecaca).withOpacity(0.25),
                        shape: BoxShape.circle),
                  ),
                ),
                // Form
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 50),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, opacity, child) => Opacity(
                        opacity: opacity,
                        child: child,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 36, vertical: 48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 40,
                                offset: const Offset(0, 10)),
                            BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6)),
                                  ],
                                ),
                                child: const Center(
                                    child: Text('K',
                                        style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white))),
                              ),
                              const SizedBox(height: 20),
                              Text(l10n.loginScreenWelcomeBack,
                                  style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827))),
                              const SizedBox(height: 8),
                              Text(l10n.loginScreenSubtitle,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      height: 1.6)),
                              const SizedBox(height: 36),

                              // Email
                              _label(l10n.formEmail),
                              const SizedBox(height: 8),
                              _inputField(
                                controller: _emailController,
                                hint: l10n.loginScreenEnterUsernameHint,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? l10n.loginScreenEmailRequired
                                    : null,
                                errorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(14)),
                                    borderSide: BorderSide(
                                        color: Color(0xFFef4444), width: 1.5)),
                                focusedErrorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(14)),
                                    borderSide: BorderSide(
                                        color: Color(0xFFef4444), width: 2)),
                              ),
                              const SizedBox(height: 20),

                              // Password
                              _label(l10n.authPassword),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  hintText: l10n.loginScreenEnterPasswordHint,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 18),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFd1d5db))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFd1d5db))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 2)),
                                  errorBorder: const OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(14)),
                                      borderSide: BorderSide(
                                          color: Color(0xFFef4444),
                                          width: 1.5)),
                                  focusedErrorBorder: const OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(14)),
                                      borderSide: BorderSide(
                                          color: Color(0xFFef4444), width: 2)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.grey),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? l10n.loginScreenPasswordRequired
                                    : (v.length < 6
                                        ? l10n.loginScreenPasswordMinLength
                                        : null),
                              ),
                              const SizedBox(height: 20),

                              // Remember me + Forgot password
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Checkbox(
                                            value: true,
                                            onChanged: (_) {},
                                            fillColor: WidgetStateProperty.all(
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(l10n.loginScreenRememberMe,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4b5563))),
                                    ],
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () {},
                                      child: Text(
                                          l10n.loginScreenForgotPassword,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // LOGIN button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed:
                                      authState.isLoading ? null : _login,
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                        Theme.of(context).colorScheme.primary),
                                    foregroundColor:
                                        WidgetStateProperty.all(Colors.white),
                                    shape: WidgetStateProperty.all(
                                        RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14))),
                                    elevation: WidgetStateProperty.resolveWith(
                                        (states) =>
                                            states.contains(WidgetState.hovered)
                                                ? 8
                                                : 0),
                                    shadowColor: WidgetStateProperty.all(
                                        Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.3)),
                                  ),
                                  child: authState.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white)))
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(l10n.authLogin.toUpperCase(),
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5)),
                                            const SizedBox(width: 10),
                                            const Icon(Icons.arrow_forward,
                                                size: 18),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Register link
                              Center(
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(l10n.loginScreenNoAccount,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600])),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () {},
                                        child: Text(
                                            l10n.loginScreenRegisterLink,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFf97316))),
                                      ),
                                    ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)));

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required String? Function(String?)? validator,
    OutlineInputBorder? errorBorder,
    OutlineInputBorder? focusedErrorBorder,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFd1d5db))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFd1d5db))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 2)),
          errorBorder: errorBorder,
          focusedErrorBorder: focusedErrorBorder,
        ),
      );

  Widget _featurePill(IconData icon, String label) => Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withOpacity(0.9)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      );
}
