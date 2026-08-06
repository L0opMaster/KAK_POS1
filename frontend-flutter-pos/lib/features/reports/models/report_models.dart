/// Report models for the POS reports module.
/// Matches the backend DTOs in ReportDtos.java.

// ──────────────────────────────────────────────
// Daily / X-Report
// ──────────────────────────────────────────────

class DailySalesSummary {
  final String date;
  final double grossSales;
  final double netSales;
  final int salesCount;

  DailySalesSummary({
    required this.date,
    required this.grossSales,
    required this.netSales,
    this.salesCount = 0,
  });

  factory DailySalesSummary.fromJson(Map<String, dynamic> json) =>
      DailySalesSummary(
        date: json['date'] as String? ?? '',
        grossSales: (json['grossSales'] as num?)?.toDouble() ?? 0,
        netSales: (json['netSales'] as num?)?.toDouble() ?? 0,
        salesCount: json['salesCount'] as int? ?? 0,
      );
}

class TopProduct {
  final int productId;
  final String nameEn;
  final String? nameKm;
  final double quantity;
  final double total;

  TopProduct({
    required this.productId,
    required this.nameEn,
    this.nameKm,
    this.quantity = 0,
    this.total = 0,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        productId: json['productId'] as int,
        nameEn: json['nameEn'] as String? ?? '',
        nameKm: json['nameKm'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}

class CashierPerformance {
  final int cashierId;
  final String cashierName;
  final double salesTotal;
  final int salesCount;

  CashierPerformance({
    required this.cashierId,
    required this.cashierName,
    this.salesTotal = 0,
    this.salesCount = 0,
  });

  factory CashierPerformance.fromJson(Map<String, dynamic> json) =>
      CashierPerformance(
        cashierId: json['cashierId'] as int,
        cashierName: json['cashierName'] as String? ?? '',
        salesTotal: (json['salesTotal'] as num?)?.toDouble() ?? 0,
        salesCount: json['salesCount'] as int? ?? 0,
      );
}

class PaymentBreakdown {
  final String method;
  final double total;
  final int count;

  PaymentBreakdown({
    required this.method,
    this.total = 0,
    this.count = 0,
  });

  factory PaymentBreakdown.fromJson(Map<String, dynamic> json) =>
      PaymentBreakdown(
        method: json['method'] as String? ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        count: json['count'] as int? ?? 0,
      );
}

class ShiftSummary {
  final int shiftId;
  final String? openedBy;
  final String? openedAt;
  final String? closedAt;
  final double openingCash;
  final double closingCash;
  final double expectedCash;
  final double variance;
  final String? status;
  final double salesTotal;
  final int salesCount;

  ShiftSummary({
    required this.shiftId,
    this.openedBy,
    this.openedAt,
    this.closedAt,
    this.openingCash = 0,
    this.closingCash = 0,
    this.expectedCash = 0,
    this.variance = 0,
    this.status,
    this.salesTotal = 0,
    this.salesCount = 0,
  });

  factory ShiftSummary.fromJson(Map<String, dynamic> json) => ShiftSummary(
        shiftId: json['shiftId'] as int,
        openedBy: json['openedBy'] as String?,
        openedAt: json['openedAt'] as String?,
        closedAt: json['closedAt'] as String?,
        openingCash: (json['openingCash'] as num?)?.toDouble() ?? 0,
        closingCash: (json['closingCash'] as num?)?.toDouble() ?? 0,
        expectedCash: (json['expectedCash'] as num?)?.toDouble() ?? 0,
        variance: (json['variance'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String?,
        salesTotal: (json['salesTotal'] as num?)?.toDouble() ?? 0,
        salesCount: json['salesCount'] as int? ?? 0,
      );
}

class DailyReportResponse {
  final DailySalesSummary? summary;
  final List<TopProduct> topProducts;
  final List<CashierPerformance> cashiers;
  final List<PaymentBreakdown> payments;
  final List<ShiftSummary> shifts;

  DailyReportResponse({
    this.summary,
    this.topProducts = const [],
    this.cashiers = const [],
    this.payments = const [],
    this.shifts = const [],
  });

  factory DailyReportResponse.fromJson(Map<String, dynamic> json) =>
      DailyReportResponse(
        summary: json['summary'] != null
            ? DailySalesSummary.fromJson(
                json['summary'] as Map<String, dynamic>)
            : null,
        topProducts: (json['topProducts'] as List<dynamic>?)
                ?.map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        cashiers: (json['cashiers'] as List<dynamic>?)
                ?.map((e) =>
                    CashierPerformance.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        payments: (json['payments'] as List<dynamic>?)
                ?.map(
                    (e) => PaymentBreakdown.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        shifts: (json['shifts'] as List<dynamic>?)
                ?.map((e) => ShiftSummary.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ──────────────────────────────────────────────
// Sales Summary Report
// ──────────────────────────────────────────────

class SalesSummaryRow {
  final String date;
  final int orders;
  final double quantity;
  final double gross;
  final double discount;
  final double tax;
  final double net;

  SalesSummaryRow({
    required this.date,
    this.orders = 0,
    this.quantity = 0,
    this.gross = 0,
    this.discount = 0,
    this.tax = 0,
    this.net = 0,
  });

  factory SalesSummaryRow.fromJson(Map<String, dynamic> json) =>
      SalesSummaryRow(
        date: json['date'] as String? ?? '',
        orders: json['orders'] as int? ?? 0,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        gross: (json['gross'] as num?)?.toDouble() ?? 0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        tax: (json['tax'] as num?)?.toDouble() ?? 0,
        net: (json['net'] as num?)?.toDouble() ?? 0,
      );
}

class SalesSummaryTotals {
  final double totalSales;
  final double gross;
  final double discount;
  final double tax;
  final double net;
  final double quantity;
  final int orders;

  SalesSummaryTotals({
    this.totalSales = 0,
    this.gross = 0,
    this.discount = 0,
    this.tax = 0,
    this.net = 0,
    this.quantity = 0,
    this.orders = 0,
  });

  factory SalesSummaryTotals.fromJson(Map<String, dynamic> json) =>
      SalesSummaryTotals(
        totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0,
        gross: (json['gross'] as num?)?.toDouble() ?? 0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        tax: (json['tax'] as num?)?.toDouble() ?? 0,
        net: (json['net'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        orders: json['orders'] as int? ?? 0,
      );
}

class FilterOption {
  final String value;
  final String label;

  FilterOption({required this.value, required this.label});

  factory FilterOption.fromJson(Map<String, dynamic> json) => FilterOption(
        value: json['value'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}

class SalesSummaryReportResponse {
  final String? fromDate;
  final String? toDate;
  final int? selectedStoreId;
  final int? selectedCashierId;
  final String? selectedPayment;
  final List<FilterOption> stores;
  final List<FilterOption> cashiers;
  final List<FilterOption> payments;
  final List<SalesSummaryRow> rows;
  final PageMeta rowsMeta;
  final SalesSummaryTotals? totals;

  /// Sales count/total per cashier for the filtered range — same shape as
  /// the dedicated "Sales by Cashier" report, shown here alongside the
  /// daily breakdown so it's visible without switching screens.
  final List<CashierPerformance> cashierBreakdown;

  SalesSummaryReportResponse({
    this.fromDate,
    this.toDate,
    this.selectedStoreId,
    this.selectedCashierId,
    this.selectedPayment,
    this.stores = const [],
    this.cashiers = const [],
    this.payments = const [],
    this.rows = const [],
    this.rowsMeta = PageMeta.empty,
    this.totals,
    this.cashierBreakdown = const [],
  });

  factory SalesSummaryReportResponse.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'];
    List<SalesSummaryRow> rows;
    PageMeta rowsMeta;
    if (rawRows is Map<String, dynamic>) {
      // Paginated Page<SalesSummaryRow> shape.
      rows = (rawRows['content'] as List<dynamic>?)
              ?.map((e) =>
                  SalesSummaryRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      rowsMeta = PageMeta.fromJson(rawRows);
    } else if (rawRows is List) {
      rows = rawRows
          .map((e) => SalesSummaryRow.fromJson(e as Map<String, dynamic>))
          .toList();
      rowsMeta = PageMeta(
        page: 0,
        size: rows.length,
        totalElements: rows.length,
        totalPages: rows.isEmpty ? 0 : 1,
      );
    } else {
      rows = [];
      rowsMeta = PageMeta.empty;
    }

    return SalesSummaryReportResponse(
      fromDate: json['fromDate'] as String?,
      toDate: json['toDate'] as String?,
      selectedStoreId: json['selectedStoreId'] as int?,
      selectedCashierId: json['selectedCashierId'] as int?,
      selectedPayment: json['selectedPayment'] as String?,
      stores: (json['stores'] as List<dynamic>?)
              ?.map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      cashiers: (json['cashiers'] as List<dynamic>?)
              ?.map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      payments: (json['payments'] as List<dynamic>?)
              ?.map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rows: rows,
      rowsMeta: rowsMeta,
      totals: json['totals'] != null
          ? SalesSummaryTotals.fromJson(json['totals'] as Map<String, dynamic>)
          : null,
      cashierBreakdown: (json['cashierBreakdown'] as List<dynamic>?)
              ?.map((e) =>
                  CashierPerformance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ──────────────────────────────────────────────
// Sales Report (detailed)
// ──────────────────────────────────────────────

class SaleItemDetail {
  final int productId;
  final String productNameEn;
  final String? productNameKm;
  final String? sku;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final double unitCost;
  final double totalCost;
  final double discount;
  final double refundedQuantity;

  SaleItemDetail({
    required this.productId,
    required this.productNameEn,
    this.productNameKm,
    this.sku,
    this.quantity = 0,
    this.unitPrice = 0,
    this.totalPrice = 0,
    this.unitCost = 0,
    this.totalCost = 0,
    this.discount = 0,
    this.refundedQuantity = 0,
  });

  factory SaleItemDetail.fromJson(Map<String, dynamic> json) => SaleItemDetail(
        productId: json['productId'] as int,
        productNameEn: json['productNameEn'] as String? ?? '',
        productNameKm: json['productNameKm'] as String?,
        sku: json['sku'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        refundedQuantity: (json['refundedQuantity'] as num?)?.toDouble() ?? 0,
      );
}

class SalesDetail {
  final int saleId;
  final String? saleNumber;
  final String? saleDate;
  final int? customerId;
  final String? customerName;
  final int? cashierId;
  final String? cashierName;
  final double grossAmount;
  final double netAmount;
  final double paidAmount;
  final double balance;
  final double taxAmount;
  final double discountAmount;
  final String? paymentMethod;
  final String? status;
  final bool creditSale;
  final int? tableId;
  final String? tableNumber;
  final List<SaleItemDetail> items;

  SalesDetail({
    required this.saleId,
    this.saleNumber,
    this.saleDate,
    this.customerId,
    this.customerName,
    this.cashierId,
    this.cashierName,
    this.grossAmount = 0,
    this.netAmount = 0,
    this.paidAmount = 0,
    this.balance = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.paymentMethod,
    this.status,
    this.creditSale = false,
    this.tableId,
    this.tableNumber,
    this.items = const [],
  });

  factory SalesDetail.fromJson(Map<String, dynamic> json) => SalesDetail(
        saleId: json['saleId'] as int,
        saleNumber: json['saleNumber'] as String?,
        saleDate: json['saleDate'] as String?,
        customerId: json['customerId'] as int?,
        customerName: json['customerName'] as String?,
        cashierId: json['cashierId'] as int?,
        cashierName: json['cashierName'] as String?,
        grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0,
        netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
        paymentMethod: json['paymentMethod'] as String?,
        status: json['status'] as String?,
        creditSale: json['creditSale'] as bool? ?? false,
        tableId: (json['tableId'] as num?)?.toInt(),
        tableNumber: json['tableNumber'] as String?,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => SaleItemDetail.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class SalesReportSummary {
  final String? fromDate;
  final String? toDate;
  final double totalGrossSales;
  final double totalNetSales;
  final double totalPaidAmount;
  final double totalBalance;
  final double totalTax;
  final double totalDiscount;
  final int totalSalesCount;
  final int totalItemsSold;
  final double averageSaleAmount;

  SalesReportSummary({
    this.fromDate,
    this.toDate,
    this.totalGrossSales = 0,
    this.totalNetSales = 0,
    this.totalPaidAmount = 0,
    this.totalBalance = 0,
    this.totalTax = 0,
    this.totalDiscount = 0,
    this.totalSalesCount = 0,
    this.totalItemsSold = 0,
    this.averageSaleAmount = 0,
  });

  factory SalesReportSummary.fromJson(Map<String, dynamic> json) =>
      SalesReportSummary(
        fromDate: json['fromDate'] as String?,
        toDate: json['toDate'] as String?,
        totalGrossSales: (json['totalGrossSales'] as num?)?.toDouble() ?? 0,
        totalNetSales: (json['totalNetSales'] as num?)?.toDouble() ?? 0,
        totalPaidAmount: (json['totalPaidAmount'] as num?)?.toDouble() ?? 0,
        totalBalance: (json['totalBalance'] as num?)?.toDouble() ?? 0,
        totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0,
        totalDiscount: (json['totalDiscount'] as num?)?.toDouble() ?? 0,
        totalSalesCount: json['totalSalesCount'] as int? ?? 0,
        totalItemsSold: json['totalItemsSold'] as int? ?? 0,
        averageSaleAmount: (json['averageSaleAmount'] as num?)?.toDouble() ?? 0,
      );
}

class SalesReportResponse {
  final SalesReportSummary? summary;
  final List<SalesDetail> sales;
  final PageMeta salesMeta;
  final List<PaymentBreakdown> paymentBreakdown;
  final List<TopProduct> topProducts;
  final List<FilterOption> customers;
  final List<FilterOption> stores;
  final List<FilterOption> cashiers;
  final List<FilterOption> paymentOptions;

  SalesReportResponse({
    this.summary,
    this.sales = const [],
    this.salesMeta = PageMeta.empty,
    this.paymentBreakdown = const [],
    this.topProducts = const [],
    this.customers = const [],
    this.stores = const [],
    this.cashiers = const [],
    this.paymentOptions = const [],
  });

  factory SalesReportResponse.fromJson(Map<String, dynamic> json) {
    final rawSales = json['sales'];
    List<SalesDetail> sales;
    PageMeta salesMeta;
    if (rawSales is Map<String, dynamic>) {
      sales = (rawSales['content'] as List<dynamic>?)
              ?.map((e) => SalesDetail.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      salesMeta = PageMeta.fromJson(rawSales);
    } else if (rawSales is List) {
      sales = rawSales
          .map((e) => SalesDetail.fromJson(e as Map<String, dynamic>))
          .toList();
      salesMeta = PageMeta(
        page: 0,
        size: sales.length,
        totalElements: sales.length,
        totalPages: sales.isEmpty ? 0 : 1,
      );
    } else {
      sales = [];
      salesMeta = PageMeta.empty;
    }

    return SalesReportResponse(
      summary: json['summary'] != null
          ? SalesReportSummary.fromJson(
              json['summary'] as Map<String, dynamic>)
          : null,
      sales: sales,
      salesMeta: salesMeta,
      paymentBreakdown: (json['paymentBreakdown'] as List<dynamic>?)
              ?.map(
                  (e) => PaymentBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topProducts: (json['topProducts'] as List<dynamic>?)
              ?.map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      customers: (json['customers'] as List<dynamic>?)
              ?.map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      stores: (json['stores'] as List<dynamic>?)
              ?.map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      cashiers: (json['cashiers'] as List<dynamic>?)
              ?.map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      paymentOptions: (json['paymentOptions'] as List<dynamic>?)
              ?.map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ──────────────────────────────────────────────
// Category Performance
// ──────────────────────────────────────────────

class CategoryPerformance {
  final int categoryId;
  final String? categoryNameEn;
  final String? categoryNameKm;
  final double total;
  final double quantity;

  CategoryPerformance({
    required this.categoryId,
    this.categoryNameEn,
    this.categoryNameKm,
    this.total = 0,
    this.quantity = 0,
  });

  factory CategoryPerformance.fromJson(Map<String, dynamic> json) =>
      CategoryPerformance(
        categoryId: json['categoryId'] as int,
        categoryNameEn: json['categoryNameEn'] as String?,
        categoryNameKm: json['categoryNameKm'] as String?,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      );
}

// ──────────────────────────────────────────────
// Monthly Sales
// ──────────────────────────────────────────────

class MonthlySales {
  final String month;
  final double total;
  final int count;

  MonthlySales({
    required this.month,
    this.total = 0,
    this.count = 0,
  });

  factory MonthlySales.fromJson(Map<String, dynamic> json) => MonthlySales(
        month: json['month'] as String? ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        count: json['count'] as int? ?? 0,
      );
}

// ──────────────────────────────────────────────
// Tax Report
// ──────────────────────────────────────────────

class TaxReport {
  final String date;
  final double taxCollected;

  TaxReport({required this.date, this.taxCollected = 0});

  factory TaxReport.fromJson(Map<String, dynamic> json) => TaxReport(
        date: json['date'] as String? ?? '',
        taxCollected: (json['taxCollected'] as num?)?.toDouble() ?? 0,
      );
}

// ──────────────────────────────────────────────
// Stock Movement
// ──────────────────────────────────────────────

class StockMovementRow {
  final int productId;
  final String? productNameEn;
  final String? movementType;
  final double quantity;
  final int? storeId;
  final String? createdAt;

  StockMovementRow({
    required this.productId,
    this.productNameEn,
    this.movementType,
    this.quantity = 0,
    this.storeId,
    this.createdAt,
  });

  factory StockMovementRow.fromJson(Map<String, dynamic> json) =>
      StockMovementRow(
        productId: json['productId'] as int,
        productNameEn: json['productNameEn'] as String?,
        movementType: json['movementType'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        storeId: json['storeId'] as int?,
        createdAt: json['createdAt'] as String?,
      );
}

// ──────────────────────────────────────────────
// Date range filter
// ──────────────────────────────────────────────

enum ReportPeriod {
  all('All'),
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This week'),
  lastWeek('Last week'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  thisYear('This Year'),
  custom('Custom');

  final String label;
  const ReportPeriod(this.label);
}

// ──────────────────────────────────────────────
// Pagination (Spring Data Page<T> JSON shape)
// ──────────────────────────────────────────────

/// Metadata for a Spring Data `Page<T>` response:
/// `{content, totalElements, totalPages, number, size}`.
///
/// `content` is parsed separately by each caller since Dart generics don't
/// survive JSON decoding.
class PageMeta {
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const PageMeta({
    this.page = 0,
    this.size = 20,
    this.totalElements = 0,
    this.totalPages = 0,
  });

  factory PageMeta.fromJson(Map<String, dynamic> json) => PageMeta(
        page: (json['number'] as num?)?.toInt() ?? 0,
        size: (json['size'] as num?)?.toInt() ?? 0,
        totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      );

  static const empty = PageMeta();
}

/// Generic wrapper for a paginated list of rows plus its [PageMeta].
class PagedResult<T> {
  final List<T> content;
  final PageMeta meta;

  const PagedResult({required this.content, required this.meta});

  factory PagedResult.empty() =>
      PagedResult<T>(content: const [], meta: PageMeta.empty);
}

// ──────────────────────────────────────────────
// Sales by Item
// ──────────────────────────────────────────────

class SalesByItemRow {
  final int productId;
  final String nameEn;
  final String? nameKm;
  final String? sku;
  final double quantitySold;
  final double grossSales;
  final double discount;
  final double netSales;

  SalesByItemRow({
    required this.productId,
    required this.nameEn,
    this.nameKm,
    this.sku,
    this.quantitySold = 0,
    this.grossSales = 0,
    this.discount = 0,
    this.netSales = 0,
  });

  factory SalesByItemRow.fromJson(Map<String, dynamic> json) =>
      SalesByItemRow(
        productId: (json['productId'] as num?)?.toInt() ?? 0,
        nameEn: json['nameEn'] as String? ?? '',
        nameKm: json['nameKm'] as String?,
        sku: json['sku'] as String?,
        quantitySold: (json['quantitySold'] as num?)?.toDouble() ?? 0,
        grossSales: (json['grossSales'] as num?)?.toDouble() ?? 0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        netSales: (json['netSales'] as num?)?.toDouble() ?? 0,
      );
}

// ──────────────────────────────────────────────
// Sales by Modifier
// ──────────────────────────────────────────────

class ModifierPerformance {
  final String groupName;
  final String optionName;
  final double quantity;
  final double revenue;

  ModifierPerformance({
    required this.groupName,
    required this.optionName,
    this.quantity = 0,
    this.revenue = 0,
  });

  factory ModifierPerformance.fromJson(Map<String, dynamic> json) =>
      ModifierPerformance(
        groupName: json['groupName'] as String? ?? '',
        optionName: json['optionName'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );
}

// ──────────────────────────────────────────────
// Discounts
// ──────────────────────────────────────────────

class DiscountRow {
  final int saleId;
  final String? saleNumber;
  final String? date;
  final String? employeeName;
  final String? discountType;
  final double amount;
  final String? reason;

  DiscountRow({
    required this.saleId,
    this.saleNumber,
    this.date,
    this.employeeName,
    this.discountType,
    this.amount = 0,
    this.reason,
  });

  factory DiscountRow.fromJson(Map<String, dynamic> json) => DiscountRow(
        saleId: (json['saleId'] as num?)?.toInt() ?? 0,
        saleNumber: json['saleNumber'] as String?,
        date: json['date'] as String?,
        employeeName: json['employeeName'] as String?,
        discountType: json['discountType'] as String?,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] as String?,
      );
}

class DiscountTotals {
  final int count;
  final double totalAmount;

  DiscountTotals({this.count = 0, this.totalAmount = 0});

  factory DiscountTotals.fromJson(Map<String, dynamic> json) =>
      DiscountTotals(
        count: (json['count'] as num?)?.toInt() ?? 0,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      );
}

/// Wraps a paginated `Page<DiscountRow>` response with an extra `totals`
/// field (same top-level-Page-plus-extra-field shape used elsewhere, e.g.
/// sales-summary's `rows`+`totals`).
class DiscountsResponse {
  final List<DiscountRow> rows;
  final PageMeta meta;
  final DiscountTotals totals;

  DiscountsResponse({
    this.rows = const [],
    this.meta = PageMeta.empty,
    DiscountTotals? totals,
  }) : totals = totals ?? DiscountTotals();

  factory DiscountsResponse.fromJson(Map<String, dynamic> json) =>
      DiscountsResponse(
        rows: (json['content'] as List<dynamic>?)
                ?.map((e) => DiscountRow.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        meta: PageMeta.fromJson(json),
        totals: json['totals'] != null
            ? DiscountTotals.fromJson(json['totals'] as Map<String, dynamic>)
            : DiscountTotals(),
      );
}

// ──────────────────────────────────────────────
// Tax range report
// ──────────────────────────────────────────────

class TaxReportRow {
  final String date;
  final double taxableSales;
  final double taxCollected;
  final int salesCount;

  TaxReportRow({
    required this.date,
    this.taxableSales = 0,
    this.taxCollected = 0,
    this.salesCount = 0,
  });

  factory TaxReportRow.fromJson(Map<String, dynamic> json) => TaxReportRow(
        date: json['date'] as String? ?? '',
        taxableSales: (json['taxableSales'] as num?)?.toDouble() ?? 0,
        taxCollected: (json['taxCollected'] as num?)?.toDouble() ?? 0,
        salesCount: (json['salesCount'] as num?)?.toInt() ?? 0,
      );
}

/// Wraps a paginated `Page<TaxReportRow>` response with an extra
/// `totalTaxCollected` field.
class TaxRangeReportResponse {
  final String? fromDate;
  final String? toDate;
  final List<TaxReportRow> rows;
  final PageMeta meta;
  final double totalTaxCollected;

  TaxRangeReportResponse({
    this.fromDate,
    this.toDate,
    this.rows = const [],
    this.meta = PageMeta.empty,
    this.totalTaxCollected = 0,
  });

  factory TaxRangeReportResponse.fromJson(Map<String, dynamic> json) =>
      TaxRangeReportResponse(
        fromDate: json['fromDate'] as String?,
        toDate: json['toDate'] as String?,
        rows: (json['content'] as List<dynamic>?)
                ?.map((e) => TaxReportRow.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        meta: PageMeta.fromJson(json),
        totalTaxCollected:
            (json['totalTaxCollected'] as num?)?.toDouble() ?? 0,
      );
}
