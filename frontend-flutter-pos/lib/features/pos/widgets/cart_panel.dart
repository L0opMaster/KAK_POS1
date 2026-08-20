import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../models/customer_models.dart';
import '../providers/cart_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/held_ticket_provider.dart';
import '../providers/table_selection_provider.dart';
import '../providers/waiting_ticket_provider.dart' as waiting;
import '../screens/table_selection_screen.dart';
import 'cart_items_list.dart';
import 'cart_totals.dart';
import 'waiting_tickets_dialog.dart';

/// Main cart panel with a horizontally scrollable header section.
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  // Header content is a fixed 34px icon/chip row in 10px vertical padding
  // (~54px natural), with generous headroom for larger accessibility text
  // scales.
  static const double _headerHeightReserve = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartState cart = ref.watch(cartProvider);
    final CartNotifier notifier = ref.read(cartProvider.notifier);

    return Stack(
      children: [
        ColoredBox(
          color: PosTheme.backgroundPageOf(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  _buildHeader(
                    context: context,
                    ref: ref,
                    cart: cart,
                    notifier: notifier,
                  ),
                  Expanded(
                    child: CartItemsList(
                      items: cart.items,
                      notifier: notifier,
                    ),
                  ),
                  // CartTotals is not wrapped in Expanded/Flexible, so as a
                  // plain Column child it would otherwise get an unbounded
                  // height constraint and simply render at its full natural
                  // content height — overflowing (rather than scrolling)
                  // whenever the panel is shorter than that, e.g. with the
                  // on-screen keyboard open. Capping it here (reserving
                  // _headerHeightReserve for the header above) gives its
                  // internal SingleChildScrollView a real bound to shrink
                  // and scroll within instead.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (constraints.maxHeight - _headerHeightReserve)
                          .clamp(0, double.infinity),
                    ),
                    child: CartTotals(
                      cart: cart,
                      notifier: notifier,
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Loading overlay
        if (cart.loading)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(0.15),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: PosTheme.primaryGreen,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Handles the header's "Clear Cart" icon.
  ///
  /// If this cart was resumed from a held ticket, clearing it here means
  /// cancelling that order outright (same as the trash icon in
  /// HeldTicketsDialog) — voiding it on the backend, which frees its table
  /// if no other open ticket still holds it — rather than just putting it
  /// back on hold ([HeldTicketNotifier.cancelResume], used elsewhere for
  /// "I'll come back to this later"). A cart that was never a held ticket
  /// just clears immediately, no confirmation needed.
  Future<void> _handleClearPressed(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
  ) async {
    if (cart.heldTicketId == null) {
      await ref.read(cartProvider.notifier).clear();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.cartPanelCancelTicketTitle),
        content: Text(
          dialogContext.l10n
              .cartPanelCancelTicketMessage('${cart.heldTicketId}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cartPanelKeepButton.toUpperCase()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
                dialogContext.l10n.cartPanelCancelTicketButton.toUpperCase(),
                style: const TextStyle(color: PosTheme.errorRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(heldTicketProvider.notifier).cancelCurrentTicket();

    if (!context.mounted) return;

    final error = ref.read(heldTicketProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error != null
            ? context.l10n.cartPanelCancelTicketFailed(error)
            : context.l10n.cartPanelTicketCancelled),
        backgroundColor: error != null ? PosTheme.errorRed : null,
      ),
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required WidgetRef ref,
    required CartState cart,
    required CartNotifier notifier,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: PosTheme.primaryGreen,
        border: Border(
          bottom: BorderSide(
            color: PosTheme.primaryGreenDark,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: PosTheme.primaryGreenDark.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Fixed receipt icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(
                PosTheme.radiusMedium,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),

          const SizedBox(width: 8),

          // Fixed ticket button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(
                PosTheme.radiusSmall,
              ),
              onTap: () {
                ref.invalidate(
                  waiting.waitingTicketsProvider,
                );

                showDialog<void>(
                  context: context,
                  builder: (_) => const WaitingTicketsDialog(),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.cartPanelTicketLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Scrollable middle section
          Expanded(
            child: _ScrollableChipRow(
              children: [
                _ItemCountChip(
                  count: cart.items.length,
                ),
                const SizedBox(width: 7),
                _OrderModeChip(
                  mode: cart.orderMode,
                  onChanged: notifier.setOrderMode,
                ),
                const SizedBox(width: 7),
                const _TableChip(),
                const SizedBox(width: 7),
                _CustomerChip(
                  customerId: cart.customerId,
                ),
                if (cart.waitingNumber != null) ...[
                  const SizedBox(width: 7),
                  _WaitingNumberChip(
                    number: cart.waitingNumber!,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Fixed clear button
          IconButton(
            tooltip: context.l10n.cartActionsClearCart,
            onPressed: cart.items.isNotEmpty && !cart.loading
                ? () => _handleClearPressed(context, ref, cart)
                : null,
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              fixedSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withOpacity(0.35),
              backgroundColor: cart.items.isNotEmpty
                  ? Colors.white.withOpacity(0.14)
                  : Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  PosTheme.radiusMedium,
                ),
              ),
            ),
            icon: const Icon(
              Icons.delete_sweep_outlined,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the current number of cart items.
class _ItemCountChip extends StatelessWidget {
  const _ItemCountChip({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = count == 0;

    return Container(
      constraints: const BoxConstraints(
        minWidth: 30,
        minHeight: 25,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isEmpty ? Colors.white.withOpacity(0.16) : Colors.white,
        borderRadius: BorderRadius.circular(
          PosTheme.radiusPill,
        ),
        border: isEmpty
            ? Border.all(
                color: Colors.white.withOpacity(0.2),
              )
            : null,
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: isEmpty
              ? Colors.white.withOpacity(0.75)
              : PosTheme.primaryGreenDark,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Tappable order-mode chip.
///
/// Each tap changes the mode in this order:
/// Dine-in → Takeaway → Delivery → Dine-in.
class _OrderModeChip extends StatelessWidget {
  const _OrderModeChip({
    required this.mode,
    required this.onChanged,
  });

  final OrderMode mode;
  final ValueChanged<OrderMode> onChanged;

  OrderMode get nextMode {
    switch (mode) {
      case OrderMode.dineIn:
        return OrderMode.takeaway;
      case OrderMode.takeaway:
        return OrderMode.delivery;
      case OrderMode.delivery:
        return OrderMode.dineIn;
    }
  }

  IconData get modeIcon {
    switch (mode) {
      case OrderMode.dineIn:
        return Icons.restaurant_rounded;
      case OrderMode.takeaway:
        return Icons.shopping_bag_outlined;
      case OrderMode.delivery:
        return Icons.delivery_dining_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(
          PosTheme.radiusPill,
        ),
        onTap: () => onChanged(nextMode),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 25,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(
              PosTheme.radiusPill,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                modeIcon,
                size: 13,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays the waiting-ticket number.
class _WaitingNumberChip extends StatelessWidget {
  const _WaitingNumberChip({
    required this.number,
  });

  final int number;

  @override
  Widget build(BuildContext context) {
    final String displayNumber = number.toString().padLeft(3, '0');

    return Container(
      constraints: const BoxConstraints(
        minHeight: 25,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: PosTheme.primaryGreenDark.withOpacity(0.55),
        borderRadius: BorderRadius.circular(
          PosTheme.radiusPill,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '#$displayNumber',
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable chip showing the customer attached to the cart (or "Walk-in" if
/// none). Tapping opens [_CustomerPickerDialog] to search/select a customer
/// via the ONLINE-only CustomerService (customer_service.dart) — there is no
/// offline customer list.
class _CustomerChip extends ConsumerWidget {
  const _CustomerChip({
    required this.customerId,
  });

  final int? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final fallbackLabel = context.l10n.cartPanelCustomerFallback('$customerId');
    final String label = customerId == null
        ? context.l10n.cartPanelWalkIn
        : ref.watch(customerByIdProvider(customerId!)).when(
              data: (customer) =>
                  customer?.localizedName(lang) ?? fallbackLabel,
              loading: () => fallbackLabel,
              error: (_, __) => fallbackLabel,
            );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PosTheme.radiusPill),
        onTap: () {
          ref.read(customerProvider.notifier).load();
          showDialog<void>(
            context: context,
            builder: (_) => const _CustomerPickerDialog(),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 25),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(PosTheme.radiusPill),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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

/// Tappable chip showing the table attached to the cart, or just "Table" if
/// none — table selection is entirely optional (counter-service shops never
/// need to touch it). Tapping pushes [TableSelectionScreen], which updates
/// both [tableSelectionProvider] and `cartProvider`'s `tableId` once the
/// user confirms — see that screen for the confirm/cancel contract.
class _TableChip extends ConsumerWidget {
  const _TableChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = ref.watch(tableSelectionProvider);
    final String label = table?.displayText ?? context.l10n.posTable;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PosTheme.radiusPill),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const TableSelectionScreen()),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 25),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(PosTheme.radiusPill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_restaurant_outlined,
                  size: 13, color: Colors.white),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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

/// Search + select dialog for attaching a customer to the current cart.
/// Loads its list from `customerProvider` (ONLINE — see customer_service.dart,
/// `/api/customers`) and calls `cartProvider.notifier.setCustomer(id)` /
/// `clearCustomer()` on selection.
class _CustomerPickerDialog extends ConsumerStatefulWidget {
  const _CustomerPickerDialog();

  @override
  ConsumerState<_CustomerPickerDialog> createState() =>
      _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<_CustomerPickerDialog> {
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(customerProvider.notifier).load(query: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final CustomerState state = ref.watch(customerProvider);

    return AlertDialog(
      title: Text(context.l10n.cartSelectCustomer),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchCtl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.cartPanelSearchCustomerHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildBody(state),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(cartProvider.notifier).clearCustomer();
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.cartPanelWalkInNoCustomerButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
      ],
    );
  }

  Widget _buildBody(CustomerState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
          child: Text(
              context.l10n.cartPanelLoadCustomersFailed('${state.error}')));
    }
    if (state.customers.isEmpty) {
      return Center(child: Text(context.l10n.cartPanelNoCustomersFound));
    }
    final lang = ref.watch(appLanguageProvider);
    return ListView.separated(
      itemCount: state.customers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final Customer customer = state.customers[index];
        final displayName = customer.localizedName(lang);
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            ),
          ),
          title: Text(displayName),
          subtitle: customer.phone != null ? Text(customer.phone!) : null,
          onTap: () {
            ref.read(cartProvider.notifier).setCustomer(customer.id);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

/// Horizontally scrollable row of header chips.
///
/// Flutter's default [ScrollBehavior] only lets touch/stylus/trackpad
/// devices drag-scroll — a plain mouse click-drag does nothing, and desktop/
/// web users instinctively reach for the mouse wheel instead, which by
/// default only scrolls vertically. This widget fixes both: it enables mouse
/// drag via a custom [ScrollBehavior], and redirects vertical wheel input
/// into horizontal scrolling.
class _ScrollableChipRow extends StatefulWidget {
  const _ScrollableChipRow({required this.children});

  final List<Widget> children;

  @override
  State<_ScrollableChipRow> createState() => _ScrollableChipRowState();
}

class _ScrollableChipRowState extends State<_ScrollableChipRow> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final double delta =
        event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
    final position = _controller.position;
    final double target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: ScrollConfiguration(
        behavior: _MouseDragScrollBehavior(),
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

/// Adds mouse to the set of devices allowed to drag-scroll, on top of the
/// platform default (touch/stylus/trackpad).
class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}
