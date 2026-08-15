import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt_models.dart';
import '../services/sale_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// receipt_provider.dart` — COPY/ADAPT NEARLY EXACTLY, full file, including
/// the independence of `setStatusFilter`/`loadAllSales` (a prior coupling
/// bug in source, already fixed there — never reintroduce it here) and the
/// deliberate absence of a `PENDING` filter chip (not a real `Sale.status`
/// value; unrelated to `PENDING_APPROVAL`, the real shift-close status from
/// Day 10 — different domain).
///
/// The "Refunded" filter/chip represents a family of two real backend
/// statuses — REFUNDED and PARTIALLY_REFUNDED both mean "some refund has
/// happened on this sale" (see `SaleService.refund()`, which accepts
/// either as a valid starting state) — not a single literal `Sale.status`
/// value.
bool saleMatchesStatusFilter(String saleStatus, String filterStatus) {
  if (filterStatus == 'REFUNDED') {
    return saleStatus == 'REFUNDED' || saleStatus == 'PARTIALLY_REFUNDED';
  }
  return saleStatus == filterStatus;
}

/// The backend's `GET /api/pos/sales?status=` query param only accepts one
/// literal status, so it can't express the REFUNDED filter's two-status
/// family — in that case the fetch is left unfiltered (`null`) and
/// [saleMatchesStatusFilter] does the narrowing client-side instead.
String? backendStatusQueryFor(String? filterStatus) =>
    filterStatus == 'REFUNDED' ? null : filterStatus;

class ReceiptState {
  const ReceiptState({
    required this.loading,
    required this.sales,
    this.selectedReceipt,
    this.error,
    this.statusFilter,
    this.searchQuery,
  });

  final bool loading;
  final List<SaleResponse> sales;
  final ReceiptResponse? selectedReceipt;
  final String? error;
  final String? statusFilter;
  final String? searchQuery;

  factory ReceiptState.initial() =>
      const ReceiptState(loading: false, sales: []);

  /// Filtered sales list based on status and search query.
  List<SaleResponse> get filteredSales {
    Iterable<SaleResponse> result = sales;

    final status = statusFilter?.trim();
    if (status != null && status.isNotEmpty) {
      result = result.where(
        (sale) => saleMatchesStatusFilter(sale.status, status),
      );
    }

    final query = searchQuery?.trim().toLowerCase();
    if (query != null && query.isNotEmpty) {
      result = result.where((sale) {
        final invoice = sale.invoiceNumber?.toLowerCase() ?? '';
        final customer = sale.customerName?.toLowerCase() ?? '';
        final id = sale.id.toString();

        return invoice.contains(query) ||
            customer.contains(query) ||
            id.contains(query);
      });
    }

    return result.toList();
  }

  ReceiptState copyWith({
    bool? loading,
    List<SaleResponse>? sales,
    ReceiptResponse? selectedReceipt,
    String? error,
    String? statusFilter,
    String? searchQuery,
    bool clearSelectedReceipt = false,
    bool clearError = false,
    bool clearStatusFilter = false,
    bool clearSearchQuery = false,
  }) {
    return ReceiptState(
      loading: loading ?? this.loading,
      sales: sales ?? this.sales,
      selectedReceipt: clearSelectedReceipt
          ? null
          : selectedReceipt ?? this.selectedReceipt,
      error: clearError ? null : error ?? this.error,
      statusFilter: clearStatusFilter
          ? null
          : statusFilter ?? this.statusFilter,
      searchQuery: clearSearchQuery ? null : searchQuery ?? this.searchQuery,
    );
  }
}

class ReceiptNotifier extends StateNotifier<ReceiptState> {
  ReceiptNotifier(this._service) : super(ReceiptState.initial());

  final SaleService _service;

  Future<void> loadActiveShiftSales() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final sales = await _service.getActiveShiftSales();
      state = state.copyWith(
        loading: false,
        sales: sales,
        clearSelectedReceipt: sales.isEmpty,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        clearSelectedReceipt: true,
      );
    }
  }

  /// [status] is the backend query param to request (already resolved via
  /// [backendStatusQueryFor] by the caller) — it intentionally does NOT
  /// also set `state.statusFilter`. Chip selection is owned exclusively by
  /// [setStatusFilter].
  Future<void> loadAllSales({String? status}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final sales = await _service.listSales(status: status);
      state = state.copyWith(
        loading: false,
        sales: sales,
        clearSelectedReceipt: sales.isEmpty,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        clearSelectedReceipt: true,
      );
    }
  }

  void setSearchQuery(String query) {
    final value = query.trim();
    state = state.copyWith(
      searchQuery: value.isEmpty ? null : value,
      clearSearchQuery: value.isEmpty,
    );
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(
      statusFilter: status,
      clearStatusFilter: status == null,
    );
  }

  Future<void> loadReceipt(int saleId) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final raw = await _service.getReceipt(saleId);
      final receipt = ReceiptResponse.fromJson(raw);
      state = state.copyWith(loading: false, selectedReceipt: receipt);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        clearSelectedReceipt: true,
      );
    }
  }
}

final receiptProvider = StateNotifierProvider<ReceiptNotifier, ReceiptState>((
  ref,
) {
  return ReceiptNotifier(ref.watch(saleServiceProvider));
});
