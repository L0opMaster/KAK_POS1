import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../models/report_models.dart';

/// Abstract service for POS reports.
abstract class ReportService {
  /// Daily / X-Report
  Future<DailyReportResponse> dailyReport(String date);

  /// Sales summary with filters
  Future<SalesSummaryReportResponse> salesSummary({
    required String from,
    required String to,
    int? storeId,
    int? cashierId,
    String? payment,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  });

  /// Detailed sales report ("Receipts")
  Future<SalesReportResponse> salesReport({
    required String from,
    required String to,
    int? customerId,
    int? storeId,
    int? cashierId,
    String? payment,
    int? fromHour,
    int? toHour,
    int? page,
    int? size,
  });

  /// Category performance ("Sales by Category")
  Future<PagedResult<CategoryPerformance>> categoryPerformance({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  });

  /// Monthly sales for a year
  Future<List<MonthlySales>> monthlySales(int year);

  /// Tax report for a single date
  Future<TaxReport> taxReport(String date);

  /// Top products
  Future<List<TopProduct>> topProducts({
    String? date,
    String? from,
    String? to,
  });

  /// Payment mix ("Sales by Payment Type")
  Future<PagedResult<PaymentBreakdown>> paymentMix({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  });

  /// Cashier / employee performance ("Sales by Employee")
  Future<PagedResult<CashierPerformance>> cashierPerformance({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  });

  /// Stock movements
  Future<List<StockMovementRow>> stockMovements({
    required String from,
    required String to,
  });

  /// Inventory valuation
  Future<Map<String, dynamic>> inventoryValuation(int? storeId);

  /// Sales by Item — paginated item table, sortable by quantity or revenue.
  Future<PagedResult<SalesByItemRow>> salesByItem({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
    String? sort,
  });

  /// Sales by Modifier
  Future<PagedResult<ModifierPerformance>> salesByModifier({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  });

  /// Discounts
  Future<DiscountsResponse> discounts({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  });

  /// Taxes over a date range (distinct from the single-date [taxReport]).
  Future<TaxRangeReportResponse> taxRangeReport({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  });
}

/// API implementation of ReportService.
class ApiReportService extends ReportService {
  ApiReportService(this._api);

  final ApiService _api;

  @override
  Future<DailyReportResponse> dailyReport(String date) async {
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/daily',
      queryParameters: {'date': date},
    );
    return DailyReportResponse.fromJson(resp);
  }

  @override
  Future<SalesSummaryReportResponse> salesSummary({
    required String from,
    required String to,
    int? storeId,
    int? cashierId,
    String? payment,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (storeId != null) 'storeId': storeId.toString(),
      if (cashierId != null) 'cashierId': cashierId.toString(),
      if (payment != null) 'payment': payment,
      if (fromHour != null) 'fromHour': fromHour.toString(),
      if (toHour != null) 'toHour': toHour.toString(),
      if (employeeId != null) 'employeeId': employeeId.toString(),
      if (page != null) 'page': page.toString(),
      if (size != null) 'size': size.toString(),
    };
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/sales-summary',
      queryParameters: params,
    );
    return SalesSummaryReportResponse.fromJson(resp);
  }

  @override
  Future<SalesReportResponse> salesReport({
    required String from,
    required String to,
    int? customerId,
    int? storeId,
    int? cashierId,
    String? payment,
    int? fromHour,
    int? toHour,
    int? page,
    int? size,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (customerId != null) 'customerId': customerId.toString(),
      if (storeId != null) 'storeId': storeId.toString(),
      if (cashierId != null) 'cashierId': cashierId.toString(),
      if (payment != null) 'payment': payment,
      if (fromHour != null) 'fromHour': fromHour.toString(),
      if (toHour != null) 'toHour': toHour.toString(),
      if (page != null) 'page': page.toString(),
      if (size != null) 'size': size.toString(),
    };
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/sales',
      queryParameters: params,
    );
    return SalesReportResponse.fromJson(resp);
  }

  @override
  Future<PagedResult<CategoryPerformance>> categoryPerformance({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (fromHour != null) 'fromHour': fromHour.toString(),
      if (toHour != null) 'toHour': toHour.toString(),
      if (employeeId != null) 'employeeId': employeeId.toString(),
      if (page != null) 'page': page.toString(),
      if (size != null) 'size': size.toString(),
    };
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/category-performance',
      queryParameters: params,
    );
    return _pagedFrom(resp, CategoryPerformance.fromJson);
  }

  @override
  Future<List<MonthlySales>> monthlySales(int year) async {
    final resp = await _api.get<List<dynamic>>(
      '/api/reports/monthly',
      queryParameters: {'year': year.toString()},
    );
    return resp
        .cast<Map<String, dynamic>>()
        .map((e) => MonthlySales.fromJson(e))
        .toList();
  }

  @override
  Future<TaxReport> taxReport(String date) async {
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/tax',
      queryParameters: {'date': date},
    );
    return TaxReport.fromJson(resp);
  }

  @override
  Future<List<TopProduct>> topProducts({
    String? date,
    String? from,
    String? to,
  }) async {
    final params = <String, dynamic>{
      if (date != null) 'date': date,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    };
    final resp = await _api.get<List<dynamic>>(
      '/api/reports/top-products',
      queryParameters: params,
    );
    return resp
        .cast<Map<String, dynamic>>()
        .map((e) => TopProduct.fromJson(e))
        .toList();
  }

  @override
  Future<PagedResult<PaymentBreakdown>> paymentMix({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (fromHour != null) 'fromHour': fromHour.toString(),
      if (toHour != null) 'toHour': toHour.toString(),
      if (employeeId != null) 'employeeId': employeeId.toString(),
      if (page != null) 'page': page.toString(),
      if (size != null) 'size': size.toString(),
    };
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/payment-mix',
      queryParameters: params,
    );
    return _pagedFrom(resp, PaymentBreakdown.fromJson);
  }

  @override
  Future<PagedResult<CashierPerformance>> cashierPerformance({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (fromHour != null) 'fromHour': fromHour.toString(),
      if (toHour != null) 'toHour': toHour.toString(),
      if (employeeId != null) 'employeeId': employeeId.toString(),
      if (page != null) 'page': page.toString(),
      if (size != null) 'size': size.toString(),
    };
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/cashier-performance',
      queryParameters: params,
    );
    return _pagedFrom(resp, CashierPerformance.fromJson);
  }

  @override
  Future<List<StockMovementRow>> stockMovements({
    required String from,
    required String to,
  }) async {
    final resp = await _api.get<List<dynamic>>(
      '/api/reports/stock-movements',
      queryParameters: {'from': from, 'to': to},
    );
    return resp
        .cast<Map<String, dynamic>>()
        .map((e) => StockMovementRow.fromJson(e))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> inventoryValuation(int? storeId) async {
    final params = <String, dynamic>{};
    if (storeId != null) params['storeId'] = storeId.toString();
    return await _api.get<Map<String, dynamic>>(
      '/api/reports/inventory-valuation',
      queryParameters: params,
    );
  }

  @override
  Future<PagedResult<SalesByItemRow>> salesByItem({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
    String? sort,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (fromHour != null) 'fromHour': fromHour.toString(),
      if (toHour != null) 'toHour': toHour.toString(),
      if (employeeId != null) 'employeeId': employeeId.toString(),
      if (page != null) 'page': page.toString(),
      if (size != null) 'size': size.toString(),
      if (sort != null) 'sort': sort,
    };
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/sales-by-item',
      queryParameters: params,
    );
    return _pagedFrom(resp, SalesByItemRow.fromJson);
  }

  @override
  Future<PagedResult<ModifierPerformance>> salesByModifier({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (fromHour != null) 'fromHour': fromHour.toString(),
      if (toHour != null) 'toHour': toHour.toString(),
      if (employeeId != null) 'employeeId': employeeId.toString(),
      if (page != null) 'page': page.toString(),
      if (size != null) 'size': size.toString(),
    };
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/sales-by-modifier',
      queryParameters: params,
    );
    return _pagedFrom(resp, ModifierPerformance.fromJson);
  }

  @override
  Future<DiscountsResponse> discounts({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (fromHour != null) 'fromHour': fromHour.toString(),
      if (toHour != null) 'toHour': toHour.toString(),
      if (employeeId != null) 'employeeId': employeeId.toString(),
      if (page != null) 'page': page.toString(),
      if (size != null) 'size': size.toString(),
    };
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/discounts',
      queryParameters: params,
    );
    return DiscountsResponse.fromJson(resp);
  }

  @override
  Future<TaxRangeReportResponse> taxRangeReport({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    int? employeeId,
    int? page,
    int? size,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (fromHour != null) 'fromHour': fromHour.toString(),
      if (toHour != null) 'toHour': toHour.toString(),
      if (employeeId != null) 'employeeId': employeeId.toString(),
      if (page != null) 'page': page.toString(),
      if (size != null) 'size': size.toString(),
    };
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/reports/tax-report',
      queryParameters: params,
    );
    return TaxRangeReportResponse.fromJson(resp);
  }

  /// Parses a top-level Spring Data `Page<T>` JSON response
  /// (`{content, totalElements, totalPages, number, size}`) into a
  /// [PagedResult].
  PagedResult<T> _pagedFrom<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final content = (json['content'] as List<dynamic>?)
            ?.map((e) => fromJson(e as Map<String, dynamic>))
            .toList() ??
        <T>[];
    return PagedResult<T>(content: content, meta: PageMeta.fromJson(json));
  }
}

// ── Providers ──

final reportServiceProvider = Provider<ReportService>((ref) {
  final api = ref.read(apiServiceProvider);
  return ApiReportService(api);
});
