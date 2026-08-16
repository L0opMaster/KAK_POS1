import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';
import '../providers/customer_provider.dart';

/// ADAPTED from the customer-selection PART of `frontend-flutter-pos/lib/
/// features/pos/widgets/cart_panel.dart` (its `_showCustomerPicker`-style
/// dialog — search field, Walk-in button, customer list). Presented here
/// as a full screen (this task's mobile UI convention for pickers reached
/// from the More tab / cart) rather than an `AlertDialog`, since a phone
/// keyboard + a dialog's fixed width don't combine well for a search list.
/// Selecting a customer calls `cartProvider.notifier.setCustomer()`;
/// "Walk-in" calls `clearCustomer()`. Both pop the screen afterward.
class CustomerPickerScreen extends ConsumerStatefulWidget {
  const CustomerPickerScreen({super.key});

  @override
  ConsumerState<CustomerPickerScreen> createState() =>
      _CustomerPickerScreenState();
}

class _CustomerPickerScreenState extends ConsumerState<CustomerPickerScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(customerProvider.notifier).load());
    _searchCtl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        ref.read(customerProvider.notifier).load(query: _searchCtl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  void _select(int? customerId) {
    if (customerId == null) {
      ref.read(cartProvider.notifier).clearCustomer();
    } else {
      ref.read(cartProvider.notifier).setCustomer(customerId);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(customerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cartSelectCustomer)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PosTheme.spacingMd),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: l10n.cartPanelSearchCustomerHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: PosTheme.spacingMd),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_outline),
                label: Text(l10n.cartPanelWalkInNoCustomerButton),
                onPressed: () => _select(null),
              ),
            ),
          ),
          const SizedBox(height: PosTheme.spacingSm),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(CustomerState state) {
    final l10n = context.l10n;
    if (state.loading && state.customers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(child: Text(l10n.cartPanelLoadCustomersFailed(state.error!)));
    }
    if (state.customers.isEmpty) {
      return Center(child: Text(l10n.cartPanelNoCustomersFound));
    }
    return ListView.builder(
      itemCount: state.customers.length,
      itemBuilder: (context, i) {
        final c = state.customers[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(
            c.resolvedDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: c.phone != null ? Text(c.phone!) : null,
          onTap: () => _select(c.id),
        );
      },
    );
  }
}
