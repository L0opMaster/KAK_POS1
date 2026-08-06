import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';

class CartActions extends ConsumerWidget {
  const CartActions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: cart.items.isNotEmpty
                ? () async {
                    final result = await showDialog<double>(
                      context: context,
                      builder: (ctx) {
                        final ctl = TextEditingController();
                        return AlertDialog(
                          title: Text(ctx.l10n.cartActionsApplyDiscountTitle),
                          content: TextField(
                            controller: ctl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                hintText: ctx.l10n.cartActionsAmountHint),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: Text(ctx.l10n.commonCancel)),
                            ElevatedButton(
                                onPressed: () {
                                  final val = double.tryParse(ctl.text) ?? 0;
                                  Navigator.of(ctx).pop(val);
                                },
                                child: Text(ctx.l10n.commonApply)),
                          ],
                        );
                      },
                    );
                    if (result != null) {
                      notifier.applyDiscount(result);
                    }
                  }
                : null,
            child: Text(context.l10n.cartDiscount),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: cart.items.isNotEmpty ? () => notifier.clear() : null,
            child: Text(context.l10n.cartActionsClearCart),
          ),
        ),
      ],
    );
  }
}
