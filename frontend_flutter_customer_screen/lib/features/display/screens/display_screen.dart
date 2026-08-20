import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/main_color_provider.dart';
import '../../../core/widgets/app_bar_actions.dart';
import '../providers/display_provider.dart';
import '../services/customer_display_relay.dart';
import '../widgets/cart_view.dart';
import '../widgets/idle_view.dart';
import '../widgets/payment_pending_view.dart';
import '../widgets/thank_you_view.dart';
import 'connect_screen.dart';

/// Root of the paired session: renders whichever view matches the POS's
/// last broadcast, with a banner if the connection drops.
class DisplayScreen extends ConsumerWidget {
  const DisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DisplayState displayState = ref.watch(displayProvider);

    if (displayState.connectionState ==
        CustomerDisplayConnectionState.disconnected) {
      // The socket dropped (POS closed the session, network hiccup, etc.) —
      // send the staff back to the pairing form rather than showing a dead
      // screen to the customer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const ConnectScreen()),
          );
        }
      });
    }

    final AppStrings strings = AppStrings(ref.watch(appLanguageProvider));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ref.watch(mainColorProvider),
        foregroundColor: Colors.white,
        title: Text(strings.displayTitle),
        actions: buildAppBarActions(
          context: context,
          ref: ref,
          onDisconnect: () => ref.read(displayProvider.notifier).disconnect(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<DisplayView>(_effectiveView(displayState)),
                child: _buildView(displayState),
              ),
            ),
          ),
          if (!displayState.posConnected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  strings.waitingForRegister,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The view actually rendered by [_buildView], folding in its
  /// null-data fallback to [DisplayView.idle] — used as the
  /// [AnimatedSwitcher] key so it only transitions on a real view change,
  /// not on every cart/message update within the same view.
  DisplayView _effectiveView(DisplayState state) {
    switch (state.view) {
      case DisplayView.cart:
        return state.cart != null ? DisplayView.cart : DisplayView.idle;
      case DisplayView.paymentPending:
        return state.paymentPending != null
            ? DisplayView.paymentPending
            : DisplayView.idle;
      case DisplayView.paymentCompleted:
        return state.paymentCompleted != null
            ? DisplayView.paymentCompleted
            : DisplayView.idle;
      case DisplayView.idle:
        return DisplayView.idle;
    }
  }

  Widget _buildView(DisplayState state) {
    switch (state.view) {
      case DisplayView.cart:
        if (state.cart != null) {
          return CartView(cart: state.cart!);
        }
        return const IdleView();
      case DisplayView.paymentPending:
        if (state.paymentPending != null) {
          return PaymentPendingView(
            pending: state.paymentPending!,
            splitUpdate: state.splitUpdate,
          );
        }
        return const IdleView();
      case DisplayView.paymentCompleted:
        if (state.paymentCompleted != null) {
          return ThankYouView(receipt: state.paymentCompleted!);
        }
        return const IdleView();
      case DisplayView.idle:
        return const IdleView();
    }
  }
}
