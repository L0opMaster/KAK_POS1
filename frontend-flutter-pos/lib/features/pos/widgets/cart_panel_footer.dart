import 'package:flutter/material.dart';

import '../../../core/utils/l10n_extensions.dart';

/// Footer for the cart panel with action buttons.
class CartPanelFooter extends StatelessWidget {
  const CartPanelFooter({super.key});

  // Natural height was ~56 (8px top/bottom padding + the default 40px-tall
  // ElevatedButtons) — pinned to an explicit 45 (20% smaller) so the
  // reduction is deterministic rather than relying on padding/button-size
  // tweaks that only approximate a percentage. Button width behavior
  // (intrinsic, not full-bleed) is unchanged — only height shrinks.
  static const double _height = 45;
  static const double _buttonHeight = 37;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.white,
      child: Row(
        children: [
          SizedBox(
            height: _buttonHeight,
            child: ElevatedButton(
              onPressed: () {},
              child: Text(context.l10n.cartPanelFooterCharge),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: _buttonHeight,
            child: ElevatedButton(
              onPressed: () {},
              child: Text(context.l10n.cartPanelFooterHold),
            ),
          ),
        ],
      ),
    );
  }
}
