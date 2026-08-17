import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/receipt_date_format.dart';
import '../../pos/models/customer_models.dart';
import '../../pos/services/customer_service.dart';
import '../../pos/services/sale_service.dart';
import '../../pos/utils/credit_status.dart';
import '../../pos/widgets/credit_repayment_dialog.dart';
import 'mobile_create_customer_screen.dart';

/// Customer detail: profile info, credit account balance/limit/usage,
/// credit sales (drilling into payment history + "Record Payment"), and
/// purchase history. Ported from `frontend-flutter-pos/lib/features/pos/
/// screens/customer_management_screen.dart`'s private `_CustomerDetailScreen`
/// (not directly importable — desktop keeps it as an unexported class in
/// the same file as the list/form screens).
///
/// Data flow matches source exactly: on load, fetches the customer, their
/// purchase history, and their credit ledger as 3 separate requests — the
/// ledger fetch is wrapped in its own try/catch that swallows errors
/// silently, so the screen still renders (profile + purchase history) even
/// if the credit-ledger endpoint fails. The credit-sales list is derived
/// from that SAME ledger fetch (`entryType == 'CREDIT_SALE'` rows) — opening
/// this screen costs exactly one ledger request total, not one per sale.
///
/// Desktop's fixed `AlertDialog` for a specific credit sale's detail/
/// payment-history/repayment-trigger becomes its own full-screen route here
/// (`_CreditSaleDetailScreen` below), matching this app's established
/// "avoid AlertDialog for variable-length scrollable content on a phone"
/// convention (see the Role permission editor from an earlier task).
class MobileCustomerDetailScreen extends ConsumerStatefulWidget {
  const MobileCustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<MobileCustomerDetailScreen> createState() =>
      _MobileCustomerDetailScreenState();
}

class _MobileCustomerDetailScreenState
    extends ConsumerState<MobileCustomerDetailScreen> {
  Customer? _customer;
  List<CustomerSaleHistoryEntry> _history = const [];
  CreditLedgerResponse? _ledger;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(customerServiceProvider);
      final customer = await service.getCustomer(widget.customerId);
      final history = await service.getCustomerHistory(widget.customerId);
      CreditLedgerResponse? ledger;
      try {
        ledger = await service.getCreditLedger(widget.customerId);
      } catch (_) {
        // Credit ledger is best-effort — the rest of the screen still
        // renders without it, matching source.
      }

      if (!mounted) return;
      setState(() {
        _customer = customer;
        _history = history;
        _ledger = ledger;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileCreateCustomerScreen(initialCustomer: _customer),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openCreditSaleDetail(int saleId) async {
    final l10n = context.l10n;
    late final SaleResponse sale;
    try {
      sale = await ref.read(saleServiceProvider).getSale(saleId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;

    final paymentHistory = (_ledger?.entries ?? const <CreditLedgerEntry>[])
        .where((e) => e.entryType == 'COLLECTION' && e.saleId == saleId)
        .toList(); // already newest-first, per the backend's ledger ordering

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CreditSaleDetailScreen(sale: sale, paymentHistory: paymentHistory),
      ),
    );
    if (result == true) _load();

    // Suppress an unused-var warning if l10n ends up unused on some builds.
    // ignore: unnecessary_statements
    l10n;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _customer?.resolvedDisplayName ?? l10n.customerManagementDetailFallbackTitle,
        ),
        actions: [
          if (_customer != null)
            IconButton(icon: const Icon(Icons.edit), onPressed: _openEdit),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(PosTheme.spacingLg),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(PosTheme.spacingMd),
                    children: [
                      _InfoCard(customer: _customer!),
                      const SizedBox(height: PosTheme.spacingMd),
                      if (_ledger != null) ...[
                        _CreditCard(customer: _customer!, ledger: _ledger!),
                        const SizedBox(height: PosTheme.spacingMd),
                        _CreditSalesCard(
                          ledger: _ledger!,
                          onTapSale: _openCreditSaleDetail,
                        ),
                        const SizedBox(height: PosTheme.spacingMd),
                      ],
                      _PurchaseHistoryCard(history: _history),
                    ],
                  ),
                ),
    );
  }
}

class _InfoCard extends ConsumerWidget {
  const _InfoCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(color: PosTheme.borderColorOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: PosTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                  ),
                  child: Icon(
                    customer.overdue ? Icons.warning_amber_rounded : Icons.person,
                    color: customer.overdue ? PosTheme.errorRed : PosTheme.primaryGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: PosTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.resolvedDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      if (customer.phone != null || customer.email != null)
                        Text(
                          [customer.phone, customer.email].whereType<String>().join(' · '),
                          style: TextStyle(
                            fontSize: PosTheme.fontSizeSm,
                            color: PosTheme.textSecondaryOf(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (customer.address != null && customer.address!.isNotEmpty) ...[
              const SizedBox(height: PosTheme.spacingSm),
              Text(
                '📍 ${customer.address}',
                style: TextStyle(
                  fontSize: PosTheme.fontSizeSm,
                  color: PosTheme.textSecondaryOf(context),
                ),
              ),
            ],
            if (customer.notes != null && customer.notes!.isNotEmpty) ...[
              const SizedBox(height: PosTheme.spacingXs),
              Text(
                '📝 ${customer.notes}',
                style: TextStyle(
                  fontSize: PosTheme.fontSizeSm,
                  color: PosTheme.textSecondaryOf(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreditCard extends ConsumerWidget {
  const _CreditCard({required this.customer, required this.ledger});

  final Customer customer;
  final CreditLedgerResponse ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final balance = ledger.creditBalance;
    final limit = customer.creditLimit;
    final usagePercent = limit > 0 ? (balance / limit * 100) : 0.0;
    final cur = watchCurrency(ref);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(color: PosTheme.borderColorOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card, size: 20, color: PosTheme.warningAmber),
                const SizedBox(width: PosTheme.spacingSm),
                Text(
                  l10n.customerManagementCreditAccountTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: PosTheme.spacingMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.customerManagementBalanceLabel,
                  style: TextStyle(
                    fontSize: PosTheme.fontSizeSm,
                    color: PosTheme.textSecondaryOf(context),
                  ),
                ),
                Text(
                  formatAmount(balance, cur),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: balance > 0
                        ? (balance > limit * 0.8 ? PosTheme.errorRed : PosTheme.warningAmber)
                        : PosTheme.successGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PosTheme.spacingXs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.customerManagementLimitPrefix} ${formatAmount(limit, cur)}',
                  style: TextStyle(fontSize: PosTheme.fontSizeXs, color: PosTheme.textHintOf(context)),
                ),
                Text(
                  '${usagePercent.toStringAsFixed(0)}% ${l10n.customerManagementUsedSuffix}',
                  style: TextStyle(fontSize: PosTheme.fontSizeXs, color: PosTheme.textHintOf(context)),
                ),
              ],
            ),
            if (limit > 0) ...[
              const SizedBox(height: PosTheme.spacingSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (usagePercent / 100).clamp(0.0, 1.0),
                  backgroundColor: PosTheme.dividerColorOf(context),
                  color: usagePercent > 80
                      ? PosTheme.errorRed
                      : usagePercent > 50
                          ? PosTheme.warningAmber
                          : PosTheme.successGreen,
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreditSalesCard extends ConsumerWidget {
  const _CreditSalesCard({required this.ledger, required this.onTapSale});

  final CreditLedgerResponse ledger;
  final void Function(int saleId) onTapSale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ledger.entries.where((e) => e.entryType == 'CREDIT_SALE').toList();
    final cur = watchCurrency(ref);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(color: PosTheme.borderColorOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.customerManagementCreditSalesTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            if (entries.isEmpty)
              Text(
                l10n.customerManagementNoCreditSales,
                style: TextStyle(fontSize: PosTheme.fontSizeSm, color: PosTheme.textHintOf(context)),
              )
            else
              ...entries.map((e) => _CreditSaleRow(entry: e, currency: cur, onTap: onTapSale)),
          ],
        ),
      ),
    );
  }
}

class _CreditSaleRow extends StatelessWidget {
  const _CreditSaleRow({required this.entry, required this.currency, required this.onTap});

  final CreditLedgerEntry entry;
  final String currency;
  final void Function(int saleId) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final remaining = entry.remainingAmount ?? 0;
    final paidSoFar = entry.amount - remaining;
    // Quick client-side approximation for this list badge only — the
    // authoritative status (which also accounts for an expiration date) is
    // fetched fresh when a specific sale is opened, exactly like source.
    final overdue = remaining > 0 && (entry.agingDays ?? 0) > 0;
    final status = remaining <= 0
        ? 'PAID'
        : overdue
            ? 'OVERDUE'
            : (paidSoFar > 0 ? 'PARTIALLY_PAID' : 'OPEN');

    return InkWell(
      onTap: entry.saleId == null ? null : () => onTap(entry.saleId!),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PosTheme.spacingSm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.invoiceNumber ?? '#${entry.saleId}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    remaining > 0
                        ? '${l10n.creditRepaymentRemainingLabel}: ${formatAmount(remaining, currency)}'
                        : formatAmount(entry.amount, currency),
                    style: TextStyle(fontSize: PosTheme.fontSizeXs, color: PosTheme.textHintOf(context)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: creditStatusColor(status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(PosTheme.radiusPill),
              ),
              child: Text(
                creditStatusLabel(l10n, status),
                style: TextStyle(
                  fontSize: PosTheme.fontSizeXs,
                  fontWeight: FontWeight.w700,
                  color: creditStatusColor(status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseHistoryCard extends ConsumerWidget {
  const _PurchaseHistoryCard({required this.history});

  final List<CustomerSaleHistoryEntry> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);

    if (history.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
          side: BorderSide(color: PosTheme.borderColorOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PosTheme.spacingXl),
          child: Center(
            child: Text(
              l10n.customerManagementNoPurchaseHistory,
              style: TextStyle(color: PosTheme.textSecondaryOf(context)),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: PosTheme.spacingSm),
          child: Text(
            l10n.customerManagementPurchaseHistoryTitle,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        ...history.map((sale) {
          final date = sale.createdAt ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: PosTheme.spacingXs),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
              side: BorderSide(color: PosTheme.borderColorOf(context)),
            ),
            child: ListTile(
              dense: true,
              title: Text(
                '${l10n.customerManagementSalePrefix}${sale.id}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${date.length >= 10 ? date.substring(0, 10) : date} · ${sale.status}',
              ),
              trailing: Text(
                formatAmount(sale.grandTotal, cur),
                style: TextStyle(fontWeight: FontWeight.w700, color: PosTheme.primaryGreen),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// One credit sale's authoritative detail — grand total, real (server-
/// computed) `creditStatus`, due date if present, and its payment history
/// (derived from the customer ledger's already-fetched `COLLECTION`
/// entries for this sale, no extra request). "Record Payment" is shown
/// only when `sale.remainingBalance > 0`, matching source.
class _CreditSaleDetailScreen extends ConsumerWidget {
  const _CreditSaleDetailScreen({required this.sale, required this.paymentHistory});

  final SaleResponse sale;
  final List<CreditLedgerEntry> paymentHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cur = sale.currency ?? watchCurrency(ref);

    return Scaffold(
      appBar: AppBar(title: Text(sale.invoiceNumber ?? '#${sale.id}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatAmount(sale.grandTotal, cur),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: creditStatusColor(sale.creditStatus).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(PosTheme.radiusPill),
                    ),
                    child: Text(
                      creditStatusLabel(l10n, sale.creditStatus),
                      style: TextStyle(
                        fontSize: PosTheme.fontSizeSm,
                        fontWeight: FontWeight.w700,
                        color: creditStatusColor(sale.creditStatus),
                      ),
                    ),
                  ),
                ],
              ),
              if (sale.creditDueAt != null) ...[
                const SizedBox(height: PosTheme.spacingXs),
                Text(
                  '${l10n.paymentScreenCreditDueLabel}: '
                  '${formatReceiptDate(parseBackendTimestamp(sale.creditDueAt) ?? DateTime.now())}',
                  style: TextStyle(fontSize: PosTheme.fontSizeSm, color: PosTheme.textHintOf(context)),
                ),
              ],
              const SizedBox(height: PosTheme.spacingLg),
              Text(
                l10n.customerManagementPaymentHistoryTitle,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: PosTheme.spacingSm),
              Expanded(
                child: paymentHistory.isEmpty
                    ? Center(
                        child: Text(
                          l10n.customerManagementNoPaymentHistory,
                          style: TextStyle(fontSize: PosTheme.fontSizeSm, color: PosTheme.textHintOf(context)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: paymentHistory.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final h = paymentHistory[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: PosTheme.spacingSm),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatReceiptDate(
                                    parseBackendTimestamp(h.createdAt) ?? DateTime.now(),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  formatAmount(h.amount.abs(), cur),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (sale.remainingBalance > 0) ...[
                const SizedBox(height: PosTheme.spacingMd),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final updated = await showCreditRepaymentDialog(context, ref, sale: sale);
                      if (updated != null && context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: Text(l10n.customerManagementRecordPaymentButton),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
