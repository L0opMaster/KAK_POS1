import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildView(displayState)),
          if (!displayState.posConnected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Text(
                  'Waiting for the register to connect...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
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
