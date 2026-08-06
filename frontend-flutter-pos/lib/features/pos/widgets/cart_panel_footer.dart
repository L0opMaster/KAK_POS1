import 'package:flutter/material.dart';

import '../../../core/utils/l10n_extensions.dart';

/// Footer for the cart panel with action buttons.
class CartPanelFooter extends StatelessWidget {
  const CartPanelFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          ElevatedButton(
              onPressed: () {},
              child: Text(context.l10n.cartPanelFooterCharge)),
          const SizedBox(width: 8),
          ElevatedButton(
              onPressed: () {},
              child: Text(context.l10n.cartPanelFooterHold)),
        ],
      ),
    );
  }
}
