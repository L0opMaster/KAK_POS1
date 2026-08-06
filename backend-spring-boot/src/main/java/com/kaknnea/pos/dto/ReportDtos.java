package com.kaknnea.pos.dto;

import lombok.Data;
import org.springframework.data.domain.Page;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

public class ReportDtos {
    @Data
    public static class DailySalesSummary {
        private String date;
        private BigDecimal grossSales;
        private BigDecimal netSales;
        private long salesCount;
    }

    @Data
    public static class TopProduct {
        private Long productId;
        private String nameEn;
        private String nameKm;
        private BigDecimal quantity;
        private BigDecimal total;
    }

    @Data
    public static class CashierPerformance {
        private Long cashierId;
        private String cashierName;
        private BigDecimal salesTotal;
        private long salesCount;
    }

    @Data
    public static class PaymentBreakdown {
        private String method;
        private BigDecimal total;
        private long count;
    }

    @Data
    public static class DailyReportResponse {
        private DailySalesSummary summary;
        private List<TopProduct> topProducts;
        private List<CashierPerformance> cashiers;
        private List<PaymentBreakdown> payments;
        private List<ShiftSummary> shifts;
    }

    @Data
    public static class PayableSummary {
        private Long supplierId;
        private BigDecimal totalPayable;
    }

    @Data
    public static class TaxReport {
        private String date;
        private BigDecimal taxCollected;
    }

    @Data
    public static class MonthlySales {
        private String month;
        private BigDecimal total;
        private long count;
    }

    @Data
    public static class CategoryPerformance {
        private Long categoryId;
        private String categoryNameEn;
        private String categoryNameKm;
        private BigDecimal total;
        private BigDecimal quantity;
    }

    @Data
    public static class StockMovementRow {
        private Long productId;
        private String productNameEn;
        private String movementType;
        private BigDecimal quantity;
        private Long storeId;
        private String createdAt;
    }

    @Data
    public static class AuditTrailRow {
        private Instant dateTime;
        private String user;
        private String module;
        private String action;
        private String reference;
        private String entity;
        private String entityId;
        private String beforeJson;
        private String afterJson;
    }

    @Data
    public static class LoginHistoryRow {
        private String user;
        private String email;
        private String ipAddress;
        private String device;
        private String browser;
        private Instant loginTime;
        private Instant logoutTime;
        private String status;
    }

    @Data
    public static class StockAdjustmentAuditRow {
        private String adjustmentNo;
        private String product;
        private BigDecimal oldQty;
        private BigDecimal newQty;
        private BigDecimal difference;
        private String reason;
        private String createdBy;
        private Instant dateTime;
    }

    @Data
    public static class StockCountVarianceRow {
        private String product;
        private String store;
        private LocalDate date;
        private BigDecimal systemQty;
        private BigDecimal countedQty;
        private BigDecimal variance;
        private String status;
    }

    @Data
    public static class CashAdjustmentRow {
        private LocalDate date;
        private String cashier;
        private BigDecimal expectedCash;
        private BigDecimal actualCash;
        private BigDecimal difference;
        private String status;
    }

    @Data
    public static class DailyZReport {
        private String date;
        private BigDecimal totalSales;
        private Integer transactionCount;
        private Map<String, BigDecimal> paymentMethodBreakdown;
        private List<ShiftSummary> shifts;
        private List<TopProduct> topProducts;
    }

    @Data
    public static class ShiftSummary {
        private Long shiftId;
        private String openedBy;
        private Instant openedAt;
        private Instant closedAt;
        private BigDecimal openingCash;
        private BigDecimal closingCash;
        private BigDecimal expectedCash;
        private BigDecimal variance;
        private String status;
        private BigDecimal salesTotal;
        private Long salesCount;
    }

    @Data
    public static class SalesReportSummary {
        private LocalDate fromDate;
        private LocalDate toDate;
        private BigDecimal totalGrossSales;
        private BigDecimal totalNetSales;
        private BigDecimal totalPaidAmount;
        private BigDecimal totalBalance;
        private BigDecimal totalTax;
        private BigDecimal totalDiscount;
        private long totalSalesCount;
        private long totalItemsSold;
        private BigDecimal averageSaleAmount;
    }

    @Data
    public static class SalesDetail {
        private Long saleId;
        private String saleNumber;
        private LocalDate saleDate;
        private Long customerId;
        private String customerName;
        private Long cashierId;
        private String cashierName;
        private BigDecimal grossAmount;
        private BigDecimal netAmount;
        private BigDecimal paidAmount;
        private BigDecimal balance;
        private BigDecimal taxAmount;
        private BigDecimal discountAmount;
        private String paymentMethod;
        private String status;
        private boolean creditSale;
        private Long tableId;
        private String tableNumber;
        private List<SaleItemDetail> items;
    }

    @Data
    public static class SaleItemDetail {
        private Long productId;
        private String productNameEn;
        private String productNameKm;
        private String sku;
        private BigDecimal quantity;
        private BigDecimal unitPrice;
        private BigDecimal totalPrice;
        private BigDecimal unitCost;
        private BigDecimal totalCost;
        private BigDecimal discount;
        private BigDecimal refundedQuantity;
    }

    @Data
    public static class SalesReportResponse {
        private SalesReportSummary summary;
        private Page<SalesDetail> sales;
        private List<PaymentBreakdown> paymentBreakdown;
        private List<TopProduct> topProducts;
        private List<SalesSummaryFilterOption> customers;
        private List<SalesSummaryFilterOption> stores;
        private List<SalesSummaryFilterOption> cashiers;
        private List<SalesSummaryFilterOption> paymentOptions;
    }

    @Data
    public static class SalesSummaryFilterOption {
        private String value;
        private String label;
    }

    @Data
    public static class SalesSummaryRow {
        private LocalDate date;
        private long orders;
        private BigDecimal quantity;
        private BigDecimal gross;
        private BigDecimal discount;
        private BigDecimal tax;
        private BigDecimal net;
    }

    @Data
    public static class SalesSummaryTotals {
        private BigDecimal totalSales;
        private BigDecimal gross;
        private BigDecimal discount;
        private BigDecimal tax;
        private BigDecimal net;
        private BigDecimal quantity;
        private long orders;
    }

    @Data
    public static class SalesSummaryReportResponse {
        private LocalDate fromDate;
        private LocalDate toDate;
        private Long selectedStoreId;
        private Long selectedCashierId;
        private String selectedPayment;
        private List<SalesSummaryFilterOption> stores;
        private List<SalesSummaryFilterOption> cashiers;
        private List<SalesSummaryFilterOption> payments;
        private Page<SalesSummaryRow> rows;
        private SalesSummaryTotals totals;
        // Sales count/total per cashier for the filtered range — same shape
        // as the dedicated "Sales by Cashier" report, shown here alongside
        // the daily breakdown so it's visible without switching screens.
        private List<CashierPerformance> cashierBreakdown;
    }

    @Data
    public static class PurchaseSummaryRow {
        private LocalDate date;
        private long purchaseOrders;
        private long goodsReceipts;
        private long supplierBills;
        private BigDecimal orderedValue;
        private BigDecimal receivedValue;
        private BigDecimal billedValue;
        private BigDecimal paidValue;
        private BigDecimal outstandingValue;
    }

    @Data
    public static class PurchaseSummaryTotals {
        private BigDecimal orderedValue;
        private BigDecimal receivedValue;
        private BigDecimal billedValue;
        private BigDecimal paidValue;
        private BigDecimal outstandingValue;
        private BigDecimal openCommitmentValue;
        private long purchaseOrders;
        private long goodsReceipts;
        private long supplierBills;
        private long suppliers;
    }

    @Data
    public static class PurchaseSummaryReportResponse {
        private LocalDate fromDate;
        private LocalDate toDate;
        private Long selectedStoreId;
        private Long selectedSupplierId;
        private List<SalesSummaryFilterOption> stores;
        private List<SalesSummaryFilterOption> suppliers;
        private List<PurchaseSummaryRow> rows;
        private PurchaseSummaryTotals totals;
    }

    @Data
    public static class PaymentMovementRow {
        private LocalDate date;
        private String direction;
        private String sourceType;
        private Long saleId;
        private Long customerId;
        private Long supplierId;
        private String documentNumber;
        private String referenceNumber;
        private String counterpartyName;
        private Long storeId;
        private String storeName;
        private String paymentMethod;
        private BigDecimal amount;
    }

    @Data
    public static class PaymentMovementTotals {
        private BigDecimal incomingAmount;
        private BigDecimal outgoingAmount;
        private BigDecimal netAmount;
        private long incomingCount;
        private long outgoingCount;
        private long totalCount;
    }

    @Data
    public static class PaymentMovementReportResponse {
        private LocalDate fromDate;
        private LocalDate toDate;
        private Long selectedStoreId;
        private String selectedMethod;
        private String selectedDirection;
        private List<SalesSummaryFilterOption> stores;
        private List<SalesSummaryFilterOption> methods;
        private List<PaymentMovementRow> rows;
        private PaymentMovementTotals totals;
    }

    @Data
    public static class ExpenseReportRow {
        private LocalDate date;
        private String expenseNumber;
        private Long categoryId;
        private String categoryNameEn;
        private String categoryNameKm;
        private String description;
        private String status;
        private String paymentMethod;
        private String reference;
        private String approvedByName;
        private BigDecimal amount;
    }

    @Data
    public static class ExpenseCategorySummary {
        private Long categoryId;
        private String categoryNameEn;
        private String categoryNameKm;
        private String color;
        private BigDecimal totalAmount;
        private long count;
    }

    @Data
    public static class ExpenseReportTotals {
        private BigDecimal totalAmount;
        private BigDecimal approvedAmount;
        private BigDecimal draftAmount;
        private long totalCount;
        private long approvedCount;
        private long draftCount;
        private long categories;
    }

    @Data
    public static class ExpenseReportResponse {
        private LocalDate fromDate;
        private LocalDate toDate;
        private Long selectedCategoryId;
        private String selectedStatus;
        private String selectedMethod;
        private List<SalesSummaryFilterOption> categories;
        private List<SalesSummaryFilterOption> methods;
        private List<ExpenseReportRow> rows;
        private List<ExpenseCategorySummary> byCategory;
        private ExpenseReportTotals totals;
    }

    @Data
    public static class ProfitLossInvoiceRow {
        private Long saleId;
        private String invoiceNumber;
        private LocalDate invoiceDate;
        private String customerName;
        private String status;
        private String paymentMethod;
        private BigDecimal grossAmount;
        private BigDecimal discountAmount;
        private BigDecimal taxAmount;
        private BigDecimal netAmount;
        private BigDecimal paidAmount;
        private BigDecimal balance;
    }

    @Data
    public static class ProfitLossExpenseRow {
        private Long expenseId;
        private LocalDate expenseDate;
        private String expenseNumber;
        private String categoryNameEn;
        private String categoryNameKm;
        private String description;
        private String paymentMethod;
        private String reference;
        private BigDecimal amount;
    }

    @Data
    public static class ProfitLossOtherIncomeRow {
        private Long incomeId;
        private LocalDate incomeDate;
        private String incomeNumber;
        private String categoryNameEn;
        private String categoryNameKm;
        private String payerName;
        private String description;
        private String paymentMethod;
        private String reference;
        private BigDecimal amount;
    }

    @Data
    public static class ProfitLossDailyRow {
        private LocalDate date;
        private long invoiceCount;
        private BigDecimal salesAmount;
        private BigDecimal expenseAmount;
        private BigDecimal profitAmount;
    }

    @Data
    public static class ProfitLossTotals {
        private long invoiceCount;
        private BigDecimal totalGrossSales;
        private BigDecimal totalDiscount;
        private BigDecimal totalTax;
        private BigDecimal totalNetSales;
        private BigDecimal totalPaidAmount;
        private BigDecimal totalBalance;
        private BigDecimal totalOtherIncome;
        private BigDecimal totalIncome;
        private BigDecimal totalDirectCost;
        private BigDecimal grossProfit;
        private BigDecimal totalPayrollExpense;
        private BigDecimal totalExpenses;
        private BigDecimal netProfit;
    }

    @Data
    public static class ProfitLossReportResponse {
        private LocalDate fromDate;
        private LocalDate toDate;
        private List<ProfitLossDailyRow> daily;
        private List<ProfitLossInvoiceRow> invoices;
        private List<ProfitLossOtherIncomeRow> otherIncomes;
        private List<ProfitLossExpenseRow> expenses;
        private ProfitLossTotals totals;
    }

    // EOD Owner Report DTOs
    @Data
    public static class EodSummary {
        private LocalDate eodDate;
        private String status;
        private String source;
        private Boolean snapshotBacked;
        private BigDecimal netSalesToday;
        private BigDecimal cashCollectedToday;
        private BigDecimal newCreditToday;
        private BigDecimal totalArBalance;
        private BigDecimal overdueGt30Days;
        private Integer totalSalesCount;
        private Integer totalPaymentsCount;
        private LocalDateTime processedAt;
    }

    @Data
    public static class EodInvoiceRow {
        private Long saleId;
        private String invoiceNo;
        private LocalDate invoiceDate;
        private String customerName;
        private BigDecimal totalSale;
        private BigDecimal paidAmount;
        private BigDecimal balance;
        private Integer daysOutstanding;
        private String agingBucket;
        private String paymentStatus;
    }

    @Data
    public static class EodCollectionSummary {
        private String paymentMethod;
        private BigDecimal totalAmount;
        private Integer transactionCount;
    }

    @Data
    public static class EodAgingSummary {
        private String agingBucket;
        private BigDecimal totalBalance;
        private Integer invoiceCount;
    }

    @Data
    public static class EodCustomerCredit {
        private Long customerId;
        private String customerName;
        private BigDecimal creditLimit;
        private BigDecimal currentBalance;
        private String status;
    }

    @Data
    public static class EodReportResponse {
        private EodSummary summary;
        private List<EodInvoiceRow> invoices;
        private List<EodCollectionSummary> collectionSummary;
        private List<EodAgingSummary> agingSummary;
        private List<EodCustomerCredit> customerCredits;
    }

    @Data
    public static class EodRunResponse {
        private Long snapshotId;
        private String status;
        private String message;
    }

    // Sales by Item
    @Data
    public static class SalesByItemRow {
        private Long productId;
        private String nameEn;
        private String nameKm;
        private String sku;
        private BigDecimal quantitySold;
        private BigDecimal grossSales;
        private BigDecimal discount;
        private BigDecimal netSales;
    }

    // Sales by Modifier
    @Data
    public static class ModifierPerformance {
        private String groupName;
        private String optionName;
        private BigDecimal quantity;
        private BigDecimal revenue;
    }

    // Discounts
    @Data
    public static class DiscountRow {
        private Long saleId;
        private String saleNumber;
        private LocalDate date;
        private String employeeName;
        private String discountType;
        private BigDecimal amount;
        private String reason;
    }

    @Data
    public static class DiscountTotals {
        private long count;
        private BigDecimal totalAmount;
    }

    @Data
    public static class DiscountReportResponse {
        private LocalDate fromDate;
        private LocalDate toDate;
        private Page<DiscountRow> rows;
        private DiscountTotals totals;
    }

    // Tax range report
    @Data
    public static class TaxReportRow {
        private LocalDate date;
        private BigDecimal taxableSales;
        private BigDecimal taxCollected;
        private long salesCount;
    }

    @Data
    public static class TaxRangeReportResponse {
        private LocalDate fromDate;
        private LocalDate toDate;
        private Page<TaxReportRow> rows;
        private BigDecimal totalTaxCollected;
    }
}
