import 'package:flutter/material.dart';

import '../../../core/config/pos_theme.dart';

/// Loyverse-inspired compact quantity stepper with +/- buttons.
class QtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const QtyStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: PosTheme.backgroundPageOf(context),
        borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
        border: Border.all(color: PosTheme.borderColorOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: quantity > 1 ? onDecrement : null,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(PosTheme.radiusSmall)),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Icon(
                Icons.remove,
                size: 16,
                color: quantity > 1
                    ? PosTheme.textPrimaryOf(context)
                    : PosTheme.textHintOf(context),
              ),
            ),
          ),
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: PosTheme.textPrimaryOf(context),
              ),
            ),
          ),
          InkWell(
            onTap: onIncrement,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(PosTheme.radiusSmall)),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(
                Icons.add,
                size: 16,
                color: PosTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
