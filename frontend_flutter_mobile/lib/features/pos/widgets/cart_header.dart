import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/table_selection_provider.dart';
import '../screens/customer_picker_screen.dart';
import '../screens/mobile_waiting_tickets_screen.dart';
import 'table_picker_sheet.dart';

IconData _orderModeIcon(OrderMode mode) {
  switch (mode) {
    case OrderMode.dineIn:
      return Icons.restaurant_rounded;
    case OrderMode.takeaway:
      return Icons.shopping_bag_outlined;
    case OrderMode.delivery:
      return Icons.delivery_dining_outlined;
  }
}

OrderMode _nextOrderMode(OrderMode mode) {
  switch (mode) {
    case OrderMode.dineIn:
      return OrderMode.takeaway;
    case OrderMode.takeaway:
      return OrderMode.delivery;
    case OrderMode.delivery:
      return OrderMode.dineIn;
  }
}

/// Ported from the order-mode/table/customer/waiting-number chip row in
/// `frontend-flutter-pos/lib/features/pos/widgets/cart_panel.dart` — the
/// header `cart_screen.dart`'s own doc comment flagged as dropped ("Day 9
/// scope", never built). COPY/ADAPT NEARLY EXACTLY for the underlying
/// state and actions (`cartProvider.notifier.setOrderMode`/`setCustomer`/
/// `clearCustomer`/`setTable`/`clearTable`, `tableSelectionProvider` for
/// display, `customerByIdProvider` to resolve the attached customer's
/// name) — all of it already existed unused in the provider layer (see
/// Day 20 investigation). MOBILE UI REIMPLEMENT of the chip row itself:
/// desktop's chips tap into an `AlertDialog`
/// (`_CustomerPickerDialog`/`TableSelector`); this pushes the existing
/// full-screen `CustomerPickerScreen` and opens the new
/// `showTablePickerSheet` bottom sheet instead — dialogs don't fit a
/// phone-width picker with a search field and keyboard.
///
/// `_getOrderModeFromCart()` in `payment_screen.dart` already reads
/// `cart.orderMode` and sends it as `'DINE_IN'|'TAKEAWAY'|'DELIVERY'` in
/// the sale-create request — this header is the missing piece that lets a
/// cashier actually change it away from the `dineIn` default.
///
/// Also carries the entry point into the waiting-tickets "queue board"
/// (`_IconChip` -> `MobileWaitingTicketsScreen`), mirroring source's
/// trigger point in `cart_panel.dart`'s header/toolbar area.
class CartHeader extends ConsumerWidget {
  const CartHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cart = ref.watch(cartProvider);
    final table = ref.watch(tableSelectionProvider);

    return Container(
      width: double.infinity,
      color: PosTheme.primaryGreen,
      padding: const EdgeInsets.fromLTRB(
        PosTheme.spacingMd,
        PosTheme.spacingSm,
        PosTheme.spacingMd,
        PosTheme.spacingMd,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              icon: _orderModeIcon(cart.orderMode),
              label: cart.orderMode.label,
              onTap: () => ref
                  .read(cartProvider.notifier)
                  .setOrderMode(_nextOrderMode(cart.orderMode)),
            ),
            const SizedBox(width: PosTheme.spacingSm),
            _Chip(
              icon: Icons.table_restaurant_outlined,
              label: table?.displayText ?? l10n.posTable,
              onTap: () => showTablePickerSheet(context, ref),
            ),
            const SizedBox(width: PosTheme.spacingSm),
            _Chip(
              icon: Icons.person_outline,
              label: cart.customerId == null
                  ? l10n.cartPanelWalkIn
                  : ref
                      .watch(customerByIdProvider(cart.customerId!))
                      .when(
                        data: (customer) =>
                            customer?.resolvedDisplayName ??
                            l10n.cartPanelCustomerFallback(
                              '${cart.customerId}',
                            ),
                        loading: () => l10n.cartPanelCustomerFallback(
                          '${cart.customerId}',
                        ),
                        error: (_, _) => l10n.cartPanelCustomerFallback(
                          '${cart.customerId}',
                        ),
                      ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CustomerPickerScreen(),
                ),
              ),
            ),
            if (cart.waitingNumber != null) ...[
              const SizedBox(width: PosTheme.spacingSm),
              _WaitingNumberChip(number: cart.waitingNumber!),
            ],
            const SizedBox(width: PosTheme.spacingSm),
            _IconChip(
              icon: Icons.list_alt_rounded,
              tooltip: l10n.waitingTicketsTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MobileWaitingTicketsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PosTheme.radiusPill),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(PosTheme.radiusPill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon-only counterpart of [_Chip] — same size/spacing/tooltip pattern,
/// used as the entry point to the waiting-tickets queue board (see
/// `frontend-flutter-pos/lib/features/pos/widgets/cart_panel.dart`'s
/// matching trigger point in its header/toolbar area).
class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PosTheme.radiusPill),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 30, minWidth: 30),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(PosTheme.radiusPill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _WaitingNumberChip extends StatelessWidget {
  const _WaitingNumberChip({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: PosTheme.primaryGreenDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(PosTheme.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            '#${number.toString().padLeft(3, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
