package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Sale;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.domain.Payment;
import com.kaknnea.pos.domain.SaleLine;
import com.kaknnea.pos.domain.SaleDiscount;
import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.domain.Expense;
import com.kaknnea.pos.domain.ExpenseCategory;
import com.kaknnea.pos.domain.OtherIncome;
import com.kaknnea.pos.domain.PayrollRun;
import com.kaknnea.pos.domain.EodSnapshot;
import com.kaknnea.pos.domain.EodInvoiceSnapshot;
import com.kaknnea.pos.domain.EodCollectionSummary;
import com.kaknnea.pos.domain.EodAgingSummary;
import com.kaknnea.pos.domain.EodCustomerCredit;
import com.kaknnea.pos.domain.GoodsReceipt;
import com.kaknnea.pos.domain.AuditLog;
import com.kaknnea.pos.domain.InventorySnapshot;
import com.kaknnea.pos.domain.LoginAudit;
import com.kaknnea.pos.domain.Shift;
import com.kaknnea.pos.domain.StockItem;
import com.kaknnea.pos.domain.StockMovement;
import com.kaknnea.pos.repository.EodSnapshotRepository;
import com.kaknnea.pos.dto.ReportDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.AuditLogRepository;
import com.kaknnea.pos.repository.BusinessSettingsRepository;
import com.kaknnea.pos.repository.ExpenseCategoryRepository;
import com.kaknnea.pos.repository.ExpenseRepository;
import com.kaknnea.pos.repository.GoodsReceiptRepository;
import com.kaknnea.pos.repository.InventorySnapshotRepository;
import com.kaknnea.pos.repository.LoginAuditRepository;
import com.kaknnea.pos.repository.PaymentRepository;
import com.kaknnea.pos.repository.OtherIncomeRepository;
import com.kaknnea.pos.repository.PayrollRunRepository;
import com.kaknnea.pos.repository.PurchaseOrderRepository;
import com.kaknnea.pos.repository.SupplierPaymentRepository;
import com.kaknnea.pos.repository.SupplierInvoiceRepository;
import com.kaknnea.pos.util.DocumentNumberUtil;
import com.kaknnea.pos.repository.PurchaseRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.ShiftRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.StockMovementRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import jakarta.persistence.EntityNotFoundException;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.ZoneId;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.YearMonth;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.function.Supplier;
import java.util.stream.Collectors;

@Service
@Transactional(readOnly = true)
public class ReportService {
        // Include the key invoice statuses so reports show the same invoices visible in the UI
        private static final java.util.Set<String> REPORT_STATUSES = java.util.Set.of("PAID", "CREDIT");
        private static final java.util.Set<String> PROFIT_LOSS_STATUSES = java.util.Set.of("PAID", "CREDIT");
        private static final ZoneId REPORT_ZONE = ZoneId.of("Asia/Phnom_Penh");
        private static final ObjectMapper MODIFIER_JSON_MAPPER = new ObjectMapper()
                        .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        private final SaleRepository saleRepository;
        private final PurchaseRepository purchaseRepository;
        private final PurchaseOrderRepository purchaseOrderRepository;
        private final GoodsReceiptRepository goodsReceiptRepository;
        private final SupplierInvoiceRepository supplierInvoiceRepository;
        private final ExpenseRepository expenseRepository;
        private final ExpenseCategoryRepository expenseCategoryRepository;
        private final OtherIncomeRepository otherIncomeRepository;
        private final PaymentRepository paymentRepository;
        private final SupplierPaymentRepository supplierPaymentRepository;
        private final StockMovementRepository stockMovementRepository;
        private final ShiftRepository shiftRepository;
        private final BusinessSettingsRepository businessSettingsRepository;
        private final PdfService pdfService;
        private final EodSnapshotRepository eodSnapshotRepository;
        private final AuditLogRepository auditLogRepository;
        private final LoginAuditRepository loginAuditRepository;
        private final InventorySnapshotRepository inventorySnapshotRepository;
        private final StockItemRepository stockItemRepository;
        private final PayrollRunRepository payrollRunRepository;

        public ReportService(SaleRepository saleRepository, PurchaseRepository purchaseRepository,
                        PurchaseOrderRepository purchaseOrderRepository,
                        GoodsReceiptRepository goodsReceiptRepository,
                        SupplierInvoiceRepository supplierInvoiceRepository,
                        ExpenseRepository expenseRepository,
                        ExpenseCategoryRepository expenseCategoryRepository,
                        OtherIncomeRepository otherIncomeRepository,
                        PaymentRepository paymentRepository,
                        SupplierPaymentRepository supplierPaymentRepository,
                        StockMovementRepository stockMovementRepository, ShiftRepository shiftRepository,
                        BusinessSettingsRepository businessSettingsRepository, PdfService pdfService,
                        EodSnapshotRepository eodSnapshotRepository,
                        AuditLogRepository auditLogRepository,
                        LoginAuditRepository loginAuditRepository,
                        InventorySnapshotRepository inventorySnapshotRepository,
                        StockItemRepository stockItemRepository,
                        PayrollRunRepository payrollRunRepository) {
                this.saleRepository = saleRepository;
                this.purchaseRepository = purchaseRepository;
                this.purchaseOrderRepository = purchaseOrderRepository;
                this.goodsReceiptRepository = goodsReceiptRepository;
                this.supplierInvoiceRepository = supplierInvoiceRepository;
                this.expenseRepository = expenseRepository;
                this.expenseCategoryRepository = expenseCategoryRepository;
                this.otherIncomeRepository = otherIncomeRepository;
                this.paymentRepository = paymentRepository;
                this.supplierPaymentRepository = supplierPaymentRepository;
                this.stockMovementRepository = stockMovementRepository;
                this.shiftRepository = shiftRepository;
                this.businessSettingsRepository = businessSettingsRepository;
                this.pdfService = pdfService;
                this.eodSnapshotRepository = eodSnapshotRepository;
                this.auditLogRepository = auditLogRepository;
                this.loginAuditRepository = loginAuditRepository;
                this.inventorySnapshotRepository = inventorySnapshotRepository;
                this.stockItemRepository = stockItemRepository;
                this.payrollRunRepository = payrollRunRepository;
        }

        public ReportDtos.DailyReportResponse dailyReport(LocalDate date) {
                var start = date.atStartOfDay().toInstant(ZoneOffset.UTC);
                var end = date.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);
                List<Sale> sales = filterSalesByRange(start, end);

                BigDecimal gross = sales.stream().map(Sale::getSubtotal).reduce(BigDecimal.ZERO, BigDecimal::add);
                BigDecimal net = sales.stream().map(Sale::getGrandTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
                long count = sales.size();

                ReportDtos.DailySalesSummary summary = new ReportDtos.DailySalesSummary();
                summary.setDate(date.toString());
                summary.setGrossSales(gross);
                summary.setNetSales(net);
                summary.setSalesCount(count);

                Map<Long, List<SaleLine>> byProduct = sales.stream()
                                .flatMap(s -> s.getLines().stream())
                                .collect(Collectors.groupingBy(sl -> sl.getProduct().getId()));

                List<ReportDtos.TopProduct> topProducts = byProduct.entrySet().stream().map(entry -> {
                        var lineList = entry.getValue();
                        var product = lineList.get(0).getProduct();
                        BigDecimal qty = lineList.stream().map(SaleLine::getQuantity).reduce(BigDecimal.ZERO,
                                        BigDecimal::add);
                        BigDecimal total = lineList.stream().map(SaleLine::getLineTotal).reduce(BigDecimal.ZERO,
                                        BigDecimal::add);
                        ReportDtos.TopProduct tp = new ReportDtos.TopProduct();
                        tp.setProductId(product.getId());
                        tp.setNameEn(product.getNameEn());
                        tp.setNameKm(product.getNameKm());
                        tp.setQuantity(qty);
                        tp.setTotal(total);
                        return tp;
                }).sorted(Comparator.comparing(ReportDtos.TopProduct::getTotal).reversed()).limit(10)
                                .collect(Collectors.toList());

                Map<Long, List<Sale>> byCashier = sales.stream()
                                .filter(s -> s.getCreatedBy() != null)
                                .collect(Collectors.groupingBy(s -> s.getCreatedBy().getId()));

                List<ReportDtos.CashierPerformance> cashiers = byCashier.entrySet().stream().map(entry -> {
                        var list = entry.getValue();
                        var user = list.get(0).getCreatedBy();
                        BigDecimal total = list.stream().map(Sale::getGrandTotal).reduce(BigDecimal.ZERO,
                                        BigDecimal::add);
                        ReportDtos.CashierPerformance perf = new ReportDtos.CashierPerformance();
                        perf.setCashierId(user.getId());
                        perf.setCashierName(user.getFullName());
                        perf.setSalesTotal(total);
                        perf.setSalesCount(list.size());
                        return perf;
                }).sorted(Comparator.comparing(ReportDtos.CashierPerformance::getSalesTotal).reversed())
                                .collect(Collectors.toList());

                ReportDtos.DailyReportResponse resp = new ReportDtos.DailyReportResponse();
                resp.setSummary(summary);
                resp.setTopProducts(topProducts);
                resp.setCashiers(cashiers);
                Map<String, List<Payment>> byMethod = sales.stream()
                                .flatMap(s -> s.getPayments().stream())
                                .collect(Collectors.groupingBy(Payment::getMethod));
                List<ReportDtos.PaymentBreakdown> payments = byMethod.entrySet().stream().map(entry -> {
                        ReportDtos.PaymentBreakdown pb = new ReportDtos.PaymentBreakdown();
                        pb.setMethod(entry.getKey());
                        pb.setTotal(entry.getValue().stream().map(Payment::getAmount).reduce(BigDecimal.ZERO,
                                        BigDecimal::add));
                        pb.setCount(entry.getValue().size());
                        return pb;
                }).collect(Collectors.toList());
                resp.setPayments(payments);
                resp.setShifts(shiftSummariesByRange(start, end));
                return resp;
        }

        public List<ReportDtos.TopProduct> topProductsByRange(LocalDate from, LocalDate to) {
                List<Sale> rangeSales = filterSalesByInvoiceDateRange(from, to);
                Map<Long, List<SaleLine>> byProduct = rangeSales.stream()
                                .flatMap(s -> s.getLines().stream())
                                .collect(Collectors.groupingBy(sl -> sl.getProduct().getId()));
                return byProduct.entrySet().stream().map(entry -> {
                        var lineList = entry.getValue();
                        var product = lineList.get(0).getProduct();
                        BigDecimal qty = lineList.stream().map(SaleLine::getQuantity)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        BigDecimal total = lineList.stream().map(SaleLine::getLineTotal)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        ReportDtos.TopProduct tp = new ReportDtos.TopProduct();
                        tp.setProductId(product.getId());
                        tp.setNameEn(product.getNameEn());
                        tp.setNameKm(product.getNameKm());
                        tp.setQuantity(qty);
                        tp.setTotal(total);
                        return tp;
                }).sorted(Comparator.comparing(ReportDtos.TopProduct::getTotal).reversed()).limit(10)
                                .collect(Collectors.toList());
        }

        public Page<ReportDtos.PaymentBreakdown> paymentMixByRange(
                        LocalDate from,
                        LocalDate to,
                        Integer fromHour,
                        Integer toHour,
                        Long employeeId,
                        int page,
                        int size) {
                List<Sale> rangeSales = filterSalesByInvoiceDateRange(from, to).stream()
                                .filter(sale -> matchesHourRange(sale, fromHour, toHour))
                                .filter(sale -> matchesEmployee(sale, employeeId))
                                .toList();
                Map<String, List<Payment>> byMethod = rangeSales.stream()
                                .flatMap(s -> s.getPayments().stream())
                                .collect(Collectors.groupingBy(Payment::getMethod));
                List<ReportDtos.PaymentBreakdown> rows = byMethod.entrySet().stream().map(entry -> {
                        ReportDtos.PaymentBreakdown pb = new ReportDtos.PaymentBreakdown();
                        pb.setMethod(entry.getKey());
                        pb.setTotal(entry.getValue().stream().map(Payment::getAmount)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                        pb.setCount(entry.getValue().size());
                        return pb;
                }).collect(Collectors.toList());
                return paginate(rows, page, size);
        }

        public ReportDtos.TaxReport taxReport(LocalDate date) {
                var start = date.atStartOfDay().toInstant(ZoneOffset.UTC);
                var end = date.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);
                BigDecimal tax = filterSalesByRange(start, end).stream()
                                .map(Sale::getTaxAmount)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);
                ReportDtos.TaxReport resp = new ReportDtos.TaxReport();
                resp.setDate(date.toString());
                resp.setTaxCollected(tax);
                return resp;
        }

        public List<ReportDtos.PayableSummary> payables() {
                return supplierInvoiceRepository.summarizeOpenPayablesBySupplier().stream()
                                .map(entry -> {
                                        ReportDtos.PayableSummary ps = new ReportDtos.PayableSummary();
                                        ps.setSupplierId((Long) entry[0]);
                                        ps.setTotalPayable((BigDecimal) entry[1]);
                                        return ps;
                                }).collect(Collectors.toList());
        }

        public List<ReportDtos.MonthlySales> monthlySales(int year) {
                Instant start = LocalDate.of(year, 1, 1).atStartOfDay().toInstant(ZoneOffset.UTC);
                Instant end = LocalDate.of(year + 1, 1, 1).atStartOfDay().toInstant(ZoneOffset.UTC);
                return saleRepository.findReportSalesByCreatedAt(start, end, REPORT_STATUSES).stream()
                                .collect(Collectors.groupingBy(
                                                s -> YearMonth.from(s.getCreatedAt().atZone(ZoneId.of("UTC")))))
                                .entrySet().stream().map(entry -> {
                                        BigDecimal total = entry.getValue().stream().map(Sale::getGrandTotal).reduce(
                                                        BigDecimal.ZERO,
                                                        BigDecimal::add);
                                        ReportDtos.MonthlySales ms = new ReportDtos.MonthlySales();
                                        ms.setMonth(entry.getKey().toString());
                                        ms.setTotal(total);
                                        ms.setCount(entry.getValue().size());
                                        return ms;
                                }).sorted(Comparator.comparing(ReportDtos.MonthlySales::getMonth))
                                .collect(Collectors.toList());
        }

        public ReportDtos.SalesSummaryReportResponse salesSummaryReport(
                        LocalDate from,
                        LocalDate to,
                        Long storeId,
                        Long cashierId,
                        String paymentMethod,
                        Integer fromHour,
                        Integer toHour,
                        int page,
                        int size) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }
                List<Sale> rangeSales = filterSalesByInvoiceDateRange(from, to);

                List<Sale> filtered = rangeSales.stream()
                                .filter(sale -> storeId == null
                                                || (sale.getShift() != null && sale.getShift().getStore() != null
                                                                && storeId.equals(sale.getShift().getStore().getId())))
                                .filter(sale -> cashierId == null || (sale.getCreatedBy() != null
                                                && cashierId.equals(sale.getCreatedBy().getId())))
                                .filter(sale -> paymentMethod == null || paymentMethod.isBlank()
                                                || "ALL".equalsIgnoreCase(paymentMethod)
                                                || sale.getPayments().stream()
                                                                .anyMatch(payment -> paymentMethod
                                                                                .equalsIgnoreCase(payment.getMethod())))
                                .filter(sale -> matchesHourRange(sale, fromHour, toHour))
                                .toList();

                Map<LocalDate, List<Sale>> byDate = filtered.stream()
                                .collect(Collectors.groupingBy(
                                                this::resolveSaleInvoiceDate,
                                                LinkedHashMap::new,
                                                Collectors.toList()));

                List<ReportDtos.SalesSummaryRow> rows = byDate.entrySet().stream()
                                .sorted(Map.Entry.comparingByKey())
                                .map(entry -> {
                                        List<Sale> sales = entry.getValue();
                                        ReportDtos.SalesSummaryRow row = new ReportDtos.SalesSummaryRow();
                                        row.setDate(entry.getKey());
                                        row.setOrders(sales.size());
                                        row.setQuantity(sales.stream()
                                                        .flatMap(sale -> sale.getLines().stream())
                                                        .map(SaleLine::getQuantity)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        row.setGross(sales.stream()
                                                        .map(Sale::getSubtotal)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        row.setDiscount(sales.stream()
                                                        .map(Sale::getDiscountAmount)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        row.setTax(sales.stream()
                                                        .map(Sale::getTaxAmount)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        row.setNet(sales.stream()
                                                        .map(Sale::getGrandTotal)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        return row;
                                })
                                .toList();

                ReportDtos.SalesSummaryTotals totals = new ReportDtos.SalesSummaryTotals();
                totals.setOrders(filtered.size());
                totals.setQuantity(filtered.stream()
                                .flatMap(sale -> sale.getLines().stream())
                                .map(SaleLine::getQuantity)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setGross(filtered.stream()
                                .map(Sale::getSubtotal)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setDiscount(filtered.stream()
                                .map(Sale::getDiscountAmount)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTax(filtered.stream()
                                .map(Sale::getTaxAmount)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setNet(filtered.stream()
                                .map(Sale::getGrandTotal)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTotalSales(totals.getNet());

                ReportDtos.SalesSummaryReportResponse response = new ReportDtos.SalesSummaryReportResponse();
                response.setFromDate(from);
                response.setToDate(to);
                response.setSelectedStoreId(storeId);
                response.setSelectedCashierId(cashierId);
                response.setSelectedPayment(paymentMethod == null || paymentMethod.isBlank() ? "ALL" : paymentMethod);
                response.setRows(paginate(rows, page, size));
                response.setTotals(totals);
                response.setStores(rangeSales.stream()
                                .filter(sale -> sale.getShift() != null && sale.getShift().getStore() != null)
                                .map(sale -> sale.getShift().getStore())
                                .collect(Collectors.toMap(
                                                store -> String.valueOf(store.getId()),
                                                store -> store,
                                                (left, right) -> left,
                                                LinkedHashMap::new))
                                .values()
                                .stream()
                                .map(store -> {
                                        ReportDtos.SalesSummaryFilterOption option = new ReportDtos.SalesSummaryFilterOption();
                                        option.setValue(String.valueOf(store.getId()));
                                        option.setLabel(store.getName());
                                        return option;
                                })
                                .toList());
                response.setCashiers(rangeSales.stream()
                                .filter(sale -> sale.getCreatedBy() != null)
                                .map(Sale::getCreatedBy)
                                .collect(Collectors.toMap(
                                                user -> String.valueOf(user.getId()),
                                                user -> user,
                                                (left, right) -> left,
                                                LinkedHashMap::new))
                                .values()
                                .stream()
                                .map(user -> {
                                        ReportDtos.SalesSummaryFilterOption option = new ReportDtos.SalesSummaryFilterOption();
                                        option.setValue(String.valueOf(user.getId()));
                                        option.setLabel(user.getFullName());
                                        return option;
                                })
                                .toList());
                response.setPayments(rangeSales.stream()
                                .flatMap(sale -> sale.getPayments().stream())
                                .map(Payment::getMethod)
                                .filter(method -> method != null && !method.isBlank())
                                .distinct()
                                .sorted()
                                .map(method -> {
                                        ReportDtos.SalesSummaryFilterOption option = new ReportDtos.SalesSummaryFilterOption();
                                        option.setValue(method);
                                        option.setLabel(method.replace('_', ' '));
                                        return option;
                                })
                                .toList());
                response.setCashierBreakdown(filtered.stream()
                                .filter(sale -> sale.getCreatedBy() != null)
                                .collect(Collectors.groupingBy(sale -> sale.getCreatedBy().getId()))
                                .values().stream()
                                .map(cashierSales -> {
                                        User cashier = cashierSales.get(0).getCreatedBy();
                                        ReportDtos.CashierPerformance perf = new ReportDtos.CashierPerformance();
                                        perf.setCashierId(cashier.getId());
                                        perf.setCashierName(cashier.getFullName());
                                        perf.setSalesCount(cashierSales.size());
                                        perf.setSalesTotal(cashierSales.stream()
                                                        .map(Sale::getGrandTotal)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        return perf;
                                })
                                .sorted(Comparator.comparing(ReportDtos.CashierPerformance::getSalesTotal).reversed())
                                .toList());
                return response;
        }

        public ReportDtos.PaymentMovementReportResponse paymentMovementReport(
                        LocalDate from,
                        LocalDate to,
                        Long storeId,
                        String method,
                        Long customerId,
                        Long supplierId,
                        String direction) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }

                String normalizedMethod = normalizeFilter(method);
                String normalizedDirection = normalizeDirection(direction);

                Instant startInstant = from.atStartOfDay().toInstant(ZoneOffset.UTC);
                Instant endInstant = to.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);
                LocalDateTime startDateTime = LocalDateTime.ofInstant(startInstant, ZoneOffset.UTC);
                LocalDateTime endDateTime = LocalDateTime.ofInstant(endInstant, ZoneOffset.UTC);

                List<ReportDtos.PaymentMovementRow> incomingRows = supplierId != null
                                ? List.of()
                                : paymentRepository.findReportPayments(Payment.PaymentStatus.COMPLETED, startDateTime, endDateTime).stream()
                                .filter(payment -> payment.getStatus() == Payment.PaymentStatus.COMPLETED)
                                .filter(payment -> storeId == null || matchesStore(resolvePaymentStore(payment), storeId))
                                .filter(payment -> customerId == null || matchesPaymentCustomer(payment, customerId))
                                .filter(payment -> matchesMethod(resolveCustomerPaymentMethod(payment), normalizedMethod))
                                .map(this::toIncomingPaymentRow)
                                .filter(row -> matchesDirection(row.getDirection(), normalizedDirection))
                                .toList();

                List<ReportDtos.PaymentMovementRow> outgoingRows = customerId != null
                                ? List.of()
                                : supplierPaymentRepository.findReportPayments(startInstant, endInstant).stream()
                                .filter(payment -> supplierId == null || matchesSupplierPaymentSupplier(payment, supplierId))
                                .filter(payment -> payment.getStatus() == null
                                                || payment.getStatus().isBlank()
                                                || "POSTED".equalsIgnoreCase(payment.getStatus()))
                                .filter(payment -> storeId == null || matchesStore(resolveSupplierPaymentStore(payment), storeId))
                                .filter(payment -> matchesMethod(resolveSupplierPaymentMethod(payment), normalizedMethod))
                                .map(this::toOutgoingPaymentRow)
                                .filter(row -> matchesDirection(row.getDirection(), normalizedDirection))
                                .toList();

                List<ReportDtos.PaymentMovementRow> rows = java.util.stream.Stream.concat(
                                incomingRows.stream(),
                                outgoingRows.stream())
                                .sorted(Comparator.comparing(ReportDtos.PaymentMovementRow::getDate).reversed()
                                                .thenComparing(row -> safeText(row.getDocumentNumber()))
                                                .thenComparing(row -> safeText(row.getReferenceNumber())))
                                .toList();

                ReportDtos.PaymentMovementTotals totals = new ReportDtos.PaymentMovementTotals();
                totals.setIncomingAmount(incomingRows.stream()
                                .map(ReportDtos.PaymentMovementRow::getAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setOutgoingAmount(outgoingRows.stream()
                                .map(ReportDtos.PaymentMovementRow::getAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setNetAmount(totals.getIncomingAmount().subtract(totals.getOutgoingAmount()));
                totals.setIncomingCount(incomingRows.size());
                totals.setOutgoingCount(outgoingRows.size());
                totals.setTotalCount(rows.size());

                ReportDtos.PaymentMovementReportResponse response = new ReportDtos.PaymentMovementReportResponse();
                response.setFromDate(from);
                response.setToDate(to);
                response.setSelectedStoreId(storeId);
                response.setSelectedMethod(normalizedMethod == null ? "ALL" : normalizedMethod);
                response.setSelectedDirection(normalizedDirection);
                response.setRows(rows);
                response.setTotals(totals);
                response.setStores(java.util.stream.Stream.concat(
                                incomingRows.stream(),
                                outgoingRows.stream())
                                .filter(row -> row.getStoreId() != null)
                                .collect(Collectors.toMap(
                                                row -> String.valueOf(row.getStoreId()),
                                                row -> row,
                                                (left, right) -> left,
                                                LinkedHashMap::new))
                                .values()
                                .stream()
                                .map(row -> {
                                        ReportDtos.SalesSummaryFilterOption option = new ReportDtos.SalesSummaryFilterOption();
                                        option.setValue(String.valueOf(row.getStoreId()));
                                        option.setLabel(row.getStoreName());
                                        return option;
                                })
                                .toList());
                response.setMethods(java.util.stream.Stream.concat(
                                incomingRows.stream().map(ReportDtos.PaymentMovementRow::getPaymentMethod),
                                outgoingRows.stream().map(ReportDtos.PaymentMovementRow::getPaymentMethod))
                                .filter(value -> value != null && !value.isBlank())
                                .distinct()
                                .sorted()
                                .map(value -> {
                                        ReportDtos.SalesSummaryFilterOption option = new ReportDtos.SalesSummaryFilterOption();
                                        option.setValue(value);
                                        option.setLabel(value.replace('_', ' '));
                                        return option;
                                })
                                .toList());
                return response;
        }

        public ReportDtos.ExpenseReportResponse expenseReport(
                        LocalDate from,
                        LocalDate to,
                        Long categoryId,
                        String status,
                        String method) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }

                String normalizedStatus = normalizeFilter(status);
                String normalizedMethod = normalizeFilter(method);

                List<Expense> filtered = expenseRepository.findAllByActiveTrueAndExpenseDateBetween(
                                from,
                                to,
                                org.springframework.data.domain.Sort.by(
                                                org.springframework.data.domain.Sort.Direction.DESC,
                                                "expenseDate",
                                                "id"))
                                .stream()
                                .filter(expense -> categoryId == null || (expense.getCategory() != null
                                                && categoryId.equals(expense.getCategory().getId())))
                                .filter(expense -> normalizedStatus == null
                                                || normalizedStatus.equalsIgnoreCase(safeText(expense.getStatus())))
                                .filter(expense -> normalizedMethod == null
                                                || normalizedMethod.equalsIgnoreCase(
                                                                safeText(expense.getPaymentMethod()).trim().toUpperCase()))
                                .toList();

                List<ReportDtos.ExpenseReportRow> rows = filtered.stream()
                                .map(this::toExpenseReportRow)
                                .toList();

                List<ReportDtos.ExpenseCategorySummary> byCategory = filtered.stream()
                                .filter(expense -> expense.getCategory() != null)
                                .collect(Collectors.groupingBy(expense -> expense.getCategory().getId(), LinkedHashMap::new, Collectors.toList()))
                                .values().stream()
                                .map(expenses -> {
                                        ExpenseCategory category = expenses.get(0).getCategory();
                                        ReportDtos.ExpenseCategorySummary summary = new ReportDtos.ExpenseCategorySummary();
                                        summary.setCategoryId(category.getId());
                                        summary.setCategoryNameEn(category.getNameEn());
                                        summary.setCategoryNameKm(category.getNameKm());
                                        summary.setColor(category.getColor());
                                        summary.setCount(expenses.size());
                                        summary.setTotalAmount(expenses.stream()
                                                        .map(Expense::getAmount)
                                                        .map(this::safe)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        return summary;
                                })
                                .sorted(Comparator.comparing(ReportDtos.ExpenseCategorySummary::getTotalAmount).reversed())
                                .toList();

                ReportDtos.ExpenseReportTotals totals = new ReportDtos.ExpenseReportTotals();
                totals.setTotalAmount(filtered.stream().map(Expense::getAmount).map(this::safe).reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setApprovedAmount(filtered.stream()
                                .filter(expense -> "APPROVED".equalsIgnoreCase(expense.getStatus()))
                                .map(Expense::getAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setDraftAmount(filtered.stream()
                                .filter(expense -> "DRAFT".equalsIgnoreCase(expense.getStatus()))
                                .map(Expense::getAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTotalCount(filtered.size());
                totals.setApprovedCount(filtered.stream().filter(expense -> "APPROVED".equalsIgnoreCase(expense.getStatus())).count());
                totals.setDraftCount(filtered.stream().filter(expense -> "DRAFT".equalsIgnoreCase(expense.getStatus())).count());
                totals.setCategories(byCategory.size());

                List<ReportDtos.SalesSummaryFilterOption> categoryOptions = expenseCategoryRepository.findAllByActiveOrderByNameEnAsc(true)
                                .stream()
                                .map(category -> {
                                        ReportDtos.SalesSummaryFilterOption option = new ReportDtos.SalesSummaryFilterOption();
                                        option.setValue(String.valueOf(category.getId()));
                                        option.setLabel(firstNonBlank(category.getNameEn(), category.getNameKm()));
                                        return option;
                                })
                                .toList();

                List<ReportDtos.SalesSummaryFilterOption> methodOptions = expenseRepository.findAllByActiveTrueAndExpenseDateBetween(
                                from,
                                to,
                                org.springframework.data.domain.Sort.by(
                                                org.springframework.data.domain.Sort.Direction.DESC,
                                                "expenseDate",
                                                "id"))
                                .stream()
                                .map(Expense::getPaymentMethod)
                                .filter(value -> value != null && !value.isBlank())
                                .map(value -> value.trim().toUpperCase())
                                .distinct()
                                .sorted()
                                .map(value -> {
                                        ReportDtos.SalesSummaryFilterOption option = new ReportDtos.SalesSummaryFilterOption();
                                        option.setValue(value);
                                        option.setLabel(value);
                                        return option;
                                })
                                .toList();

                ReportDtos.ExpenseReportResponse response = new ReportDtos.ExpenseReportResponse();
                response.setFromDate(from);
                response.setToDate(to);
                response.setSelectedCategoryId(categoryId);
                response.setSelectedStatus(normalizedStatus == null ? "ALL" : normalizedStatus);
                response.setSelectedMethod(normalizedMethod == null ? "ALL" : normalizedMethod);
                response.setCategories(categoryOptions);
                response.setMethods(methodOptions);
                response.setRows(rows);
                response.setByCategory(byCategory);
                response.setTotals(totals);
                return response;
        }

        public ReportDtos.ProfitLossReportResponse profitLossReport(LocalDate from, LocalDate to) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }

                List<Sale> sales = filterSalesByInvoiceDateRange(from, to).stream()
                                .filter(sale -> PROFIT_LOSS_STATUSES.contains(safeText(sale.getStatus()).toUpperCase()))
                                .sorted(Comparator.comparing(Sale::getCreatedAt, Comparator.nullsLast(Comparator.reverseOrder()))
                                                .thenComparing(Sale::getId, Comparator.nullsLast(Comparator.reverseOrder())))
                                .toList();

                List<Expense> approvedExpenses = expenseRepository.findAllByActiveTrueAndExpenseDateBetween(
                                from,
                                to,
                                org.springframework.data.domain.Sort.by(
                                                org.springframework.data.domain.Sort.Direction.DESC,
                                                "expenseDate",
                                                "id"))
                                .stream()
                                .filter(expense -> "APPROVED".equalsIgnoreCase(safeText(expense.getStatus())))
                                .toList();

                List<OtherIncome> approvedOtherIncomes = otherIncomeRepository.findAllByActiveTrueAndIncomeDateBetween(
                                from,
                                to,
                                org.springframework.data.domain.Sort.by(
                                                org.springframework.data.domain.Sort.Direction.DESC,
                                                "incomeDate",
                                                "id"))
                                .stream()
                                .filter(income -> "APPROVED".equalsIgnoreCase(safeText(income.getStatus())))
                                .toList();

                List<com.kaknnea.pos.domain.SupplierInvoice> supplierInvoices = supplierInvoiceRepository.findReportInvoices(from, to).stream()
                                .filter(invoice -> !java.util.Set.of("DRAFT", "VOID", "CANCELLED")
                                                .contains(safeText(invoice.getStatus()).toUpperCase()))
                                .toList();

                List<PayrollRun> payrollRuns = payrollRunRepository.findAllByActiveTrue(
                                org.springframework.data.domain.Sort.by(
                                                org.springframework.data.domain.Sort.Direction.DESC,
                                                "payDate",
                                                "id"))
                                .stream()
                                .filter(run -> matchesRange(run.getPayDate(), from, to))
                                .filter(run -> java.util.Set.of("APPROVED", "PAID")
                                                .contains(safeText(run.getStatus()).toUpperCase()))
                                .toList();

                List<ReportDtos.ProfitLossInvoiceRow> invoiceRows = sales.stream()
                                .map(this::toProfitLossInvoiceRow)
                                .toList();

                List<ReportDtos.ProfitLossExpenseRow> expenseRows = approvedExpenses.stream()
                                .map(this::toProfitLossExpenseRow)
                                .collect(Collectors.toCollection(ArrayList::new));
                payrollRuns.stream()
                                .map(this::toProfitLossPayrollExpenseRow)
                                .forEach(expenseRows::add);

                List<ReportDtos.ProfitLossOtherIncomeRow> otherIncomeRows = approvedOtherIncomes.stream()
                                .map(this::toProfitLossOtherIncomeRow)
                                .toList();

                Map<LocalDate, List<Sale>> salesByDate = sales.stream()
                                .collect(Collectors.groupingBy(
                                                this::resolveSaleInvoiceDate));
                Map<LocalDate, List<Expense>> expensesByDate = approvedExpenses.stream()
                                .collect(Collectors.groupingBy(Expense::getExpenseDate));
                Map<LocalDate, List<PayrollRun>> payrollByDate = payrollRuns.stream()
                                .collect(Collectors.groupingBy(PayrollRun::getPayDate));
                Map<LocalDate, List<OtherIncome>> otherIncomesByDate = approvedOtherIncomes.stream()
                                .collect(Collectors.groupingBy(OtherIncome::getIncomeDate));
                Map<LocalDate, List<com.kaknnea.pos.domain.SupplierInvoice>> supplierInvoicesByDate = supplierInvoices
                                .stream()
                                .collect(Collectors.groupingBy(com.kaknnea.pos.domain.SupplierInvoice::getInvoiceDate));

                List<ReportDtos.ProfitLossDailyRow> dailyRows = new ArrayList<>();
                for (LocalDate date = from; !date.isAfter(to); date = date.plusDays(1)) {
                        List<Sale> dateSales = salesByDate.getOrDefault(date, List.of());
                        List<Expense> dateExpenses = expensesByDate.getOrDefault(date, List.of());
                        List<PayrollRun> datePayrollRuns = payrollByDate.getOrDefault(date, List.of());
                        List<OtherIncome> dateOtherIncomes = otherIncomesByDate.getOrDefault(date, List.of());
                        List<com.kaknnea.pos.domain.SupplierInvoice> dateSupplierInvoices = supplierInvoicesByDate
                                        .getOrDefault(date, List.of());

                        BigDecimal salesAmount = dateSales.stream()
                                        .map(Sale::getGrandTotal)
                                        .map(this::safe)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        BigDecimal otherIncomeAmount = dateOtherIncomes.stream()
                                        .map(OtherIncome::getAmount)
                                        .map(this::safe)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        BigDecimal expenseAmount = dateExpenses.stream()
                                        .map(Expense::getAmount)
                                        .map(this::safe)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        BigDecimal payrollAmount = datePayrollRuns.stream()
                                        .map(PayrollRun::getTotalGross)
                                        .map(this::safe)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        BigDecimal directCostAmount = dateSupplierInvoices.stream()
                                        .map(com.kaknnea.pos.domain.SupplierInvoice::getTotalAmount)
                                        .map(this::safe)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);

                        ReportDtos.ProfitLossDailyRow row = new ReportDtos.ProfitLossDailyRow();
                        row.setDate(date);
                        row.setInvoiceCount(dateSales.size());
                        row.setSalesAmount(salesAmount.add(otherIncomeAmount));
                        row.setExpenseAmount(expenseAmount.add(payrollAmount));
                        row.setProfitAmount(salesAmount.add(otherIncomeAmount).subtract(directCostAmount).subtract(expenseAmount).subtract(payrollAmount));
                        dailyRows.add(row);
                }

                ReportDtos.ProfitLossTotals totals = new ReportDtos.ProfitLossTotals();
                totals.setInvoiceCount(sales.size());
                totals.setTotalGrossSales(sales.stream()
                                .map(Sale::getSubtotal)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTotalDiscount(sales.stream()
                                .map(Sale::getDiscountAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTotalTax(sales.stream()
                                .map(Sale::getTaxAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTotalNetSales(sales.stream()
                                .map(Sale::getGrandTotal)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTotalPaidAmount(sales.stream()
                                .map(this::salesReportPaidAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTotalBalance(sales.stream()
                                .map(this::salesReportBalance)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTotalOtherIncome(approvedOtherIncomes.stream()
                                .map(OtherIncome::getAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setTotalIncome(totals.getTotalNetSales().add(totals.getTotalOtherIncome()));
                totals.setTotalDirectCost(supplierInvoices.stream()
                                .map(com.kaknnea.pos.domain.SupplierInvoice::getTotalAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                totals.setGrossProfit(totals.getTotalIncome().subtract(totals.getTotalDirectCost()));
                BigDecimal payrollExpenseTotal = payrollRuns.stream()
                                .map(PayrollRun::getTotalGross)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);
                totals.setTotalPayrollExpense(payrollExpenseTotal);
                totals.setTotalExpenses(approvedExpenses.stream()
                                .map(Expense::getAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add)
                                .add(payrollExpenseTotal));
                totals.setNetProfit(totals.getGrossProfit().subtract(totals.getTotalExpenses()));

                ReportDtos.ProfitLossReportResponse response = new ReportDtos.ProfitLossReportResponse();
                response.setFromDate(from);
                response.setToDate(to);
                response.setDaily(dailyRows);
                response.setInvoices(invoiceRows);
                response.setOtherIncomes(otherIncomeRows);
                response.setExpenses(expenseRows);
                response.setTotals(totals);
                return response;
        }

        public ReportDtos.PurchaseSummaryReportResponse purchaseSummaryReport(
                        LocalDate from,
                        LocalDate to,
                        Long storeId,
                        Long supplierId) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }

                Instant start = from.atStartOfDay().toInstant(ZoneOffset.UTC);
                Instant end = to.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);

                List<com.kaknnea.pos.domain.PurchaseOrder> purchaseOrders = purchaseOrderRepository.findReportOrders(start, end).stream()
                                .filter(order -> storeId == null || (order.getStore() != null
                                                && storeId.equals(order.getStore().getId())))
                                .filter(order -> supplierId == null || (order.getSupplier() != null
                                                && supplierId.equals(order.getSupplier().getId())))
                                .toList();

                List<GoodsReceipt> goodsReceipts = goodsReceiptRepository.findReportReceipts(start, end).stream()
                                .filter(receipt -> storeId == null || (receipt.getStore() != null
                                                && storeId.equals(receipt.getStore().getId())))
                                .filter(receipt -> supplierId == null || (receipt.getSupplier() != null
                                                && supplierId.equals(receipt.getSupplier().getId())))
                                .toList();

                List<com.kaknnea.pos.domain.SupplierInvoice> supplierInvoices = supplierInvoiceRepository.findReportInvoices(from, to).stream()
                                .filter(invoice -> storeId == null || (invoice.getStore() != null
                                                && storeId.equals(invoice.getStore().getId())))
                                .filter(invoice -> supplierId == null || (invoice.getSupplier() != null
                                                && supplierId.equals(invoice.getSupplier().getId())))
                                .toList();

                Map<LocalDate, ReportDtos.PurchaseSummaryRow> rowsByDate = new LinkedHashMap<>();
                purchaseOrders.stream()
                                .sorted(Comparator.comparing(this::resolvePurchaseOrderDate))
                                .forEach(order -> {
                                        LocalDate date = resolvePurchaseOrderDate(order);
                                        ReportDtos.PurchaseSummaryRow row = rowsByDate.computeIfAbsent(date,
                                                        this::emptyPurchaseSummaryRow);
                                        row.setPurchaseOrders(row.getPurchaseOrders() + 1);
                                        row.setOrderedValue(row.getOrderedValue().add(safe(order.getTotalAmount())));
                                });
                goodsReceipts.stream()
                                .sorted(Comparator.comparing(this::resolveGoodsReceiptDate))
                                .forEach(receipt -> {
                                        LocalDate date = resolveGoodsReceiptDate(receipt);
                                        ReportDtos.PurchaseSummaryRow row = rowsByDate.computeIfAbsent(date,
                                                        this::emptyPurchaseSummaryRow);
                                        row.setGoodsReceipts(row.getGoodsReceipts() + 1);
                                        row.setReceivedValue(row.getReceivedValue().add(safe(receipt.getTotalAmount())));
                                });
                supplierInvoices.stream()
                                .sorted(Comparator.comparing(com.kaknnea.pos.domain.SupplierInvoice::getInvoiceDate))
                                .forEach(invoice -> {
                                        LocalDate date = invoice.getInvoiceDate();
                                        ReportDtos.PurchaseSummaryRow row = rowsByDate.computeIfAbsent(date,
                                                        this::emptyPurchaseSummaryRow);
                                        row.setSupplierBills(row.getSupplierBills() + 1);
                                        row.setBilledValue(row.getBilledValue().add(safe(invoice.getTotalAmount())));
                                        row.setPaidValue(row.getPaidValue().add(safe(invoice.getPaidAmount())));
                                        row.setOutstandingValue(
                                                        row.getOutstandingValue().add(safe(invoice.getOutstandingAmount())));
                                });

                List<ReportDtos.PurchaseSummaryRow> rows = rowsByDate.values().stream().toList();

                ReportDtos.PurchaseSummaryTotals totals = new ReportDtos.PurchaseSummaryTotals();
                totals.setPurchaseOrders(purchaseOrders.size());
                totals.setGoodsReceipts(goodsReceipts.size());
                totals.setSupplierBills(supplierInvoices.size());
                totals.setSuppliers(distinctSupplierCount(purchaseOrders, goodsReceipts, supplierInvoices));
                totals.setOrderedValue(sumPurchaseOrderAmounts(purchaseOrders));
                totals.setReceivedValue(sumGoodsReceiptAmounts(goodsReceipts));
                totals.setBilledValue(sumSupplierInvoiceField(supplierInvoices, com.kaknnea.pos.domain.SupplierInvoice::getTotalAmount));
                totals.setPaidValue(sumSupplierInvoiceField(supplierInvoices, com.kaknnea.pos.domain.SupplierInvoice::getPaidAmount));
                totals.setOutstandingValue(
                                sumSupplierInvoiceField(supplierInvoices, com.kaknnea.pos.domain.SupplierInvoice::getOutstandingAmount));
                totals.setOpenCommitmentValue(purchaseOrders.stream()
                                .filter(order -> order.getStatus() != null && !java.util.Set.of("RECEIVED", "CLOSED", "CANCELLED")
                                                .contains(order.getStatus().toUpperCase()))
                                .map(com.kaknnea.pos.domain.PurchaseOrder::getTotalAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));

                ReportDtos.PurchaseSummaryReportResponse response = new ReportDtos.PurchaseSummaryReportResponse();
                response.setFromDate(from);
                response.setToDate(to);
                response.setSelectedStoreId(storeId);
                response.setSelectedSupplierId(supplierId);
                response.setRows(rows);
                response.setTotals(totals);
                response.setStores(java.util.stream.Stream.concat(
                                purchaseOrders.stream()
                                                .map(com.kaknnea.pos.domain.PurchaseOrder::getStore),
                                java.util.stream.Stream.concat(
                                                goodsReceipts.stream().map(GoodsReceipt::getStore),
                                                supplierInvoices.stream().map(com.kaknnea.pos.domain.SupplierInvoice::getStore)))
                                .filter(java.util.Objects::nonNull)
                                .collect(Collectors.toMap(
                                                store -> String.valueOf(store.getId()),
                                                store -> store,
                                                (left, right) -> left,
                                                LinkedHashMap::new))
                                .values()
                                .stream()
                                .map(store -> {
                                        ReportDtos.SalesSummaryFilterOption option = new ReportDtos.SalesSummaryFilterOption();
                                        option.setValue(String.valueOf(store.getId()));
                                        option.setLabel(store.getName());
                                        return option;
                                })
                                .toList());
                response.setSuppliers(java.util.stream.Stream.concat(
                                purchaseOrders.stream().map(com.kaknnea.pos.domain.PurchaseOrder::getSupplier),
                                java.util.stream.Stream.concat(
                                                goodsReceipts.stream().map(GoodsReceipt::getSupplier),
                                                supplierInvoices.stream().map(com.kaknnea.pos.domain.SupplierInvoice::getSupplier)))
                                .filter(java.util.Objects::nonNull)
                                .collect(Collectors.toMap(
                                                supplier -> String.valueOf(supplier.getId()),
                                                supplier -> supplier,
                                                (left, right) -> left,
                                                LinkedHashMap::new))
                                .values()
                                .stream()
                                .map(supplier -> {
                                        ReportDtos.SalesSummaryFilterOption option = new ReportDtos.SalesSummaryFilterOption();
                                        option.setValue(String.valueOf(supplier.getId()));
                                        option.setLabel(supplier.getName());
                                        return option;
                                })
                                .toList());
                return response;
        }

        public Page<ReportDtos.CategoryPerformance> categoryPerformance(
                        LocalDate from,
                        LocalDate to,
                        Integer fromHour,
                        Integer toHour,
                        Long employeeId,
                        int page,
                        int size) {
                var start = from.atStartOfDay().toInstant(ZoneOffset.UTC);
                var end = to.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);
                List<ReportDtos.CategoryPerformance> rows = filterSalesByRange(start, end).stream()
                                .filter(sale -> matchesHourRange(sale, fromHour, toHour))
                                .filter(sale -> matchesEmployee(sale, employeeId))
                                .flatMap(s -> s.getLines().stream())
                                .filter(line -> line.getProduct().getCategory() != null)
                                .collect(Collectors.groupingBy(line -> line.getProduct().getCategory().getId()))
                                .entrySet().stream().map(entry -> {
                                        var lineList = entry.getValue();
                                        var cat = lineList.get(0).getProduct().getCategory();
                                        BigDecimal total = lineList.stream().map(SaleLine::getLineTotal).reduce(
                                                        BigDecimal.ZERO,
                                                        BigDecimal::add);
                                        BigDecimal qty = lineList.stream().map(SaleLine::getQuantity).reduce(
                                                        BigDecimal.ZERO,
                                                        BigDecimal::add);
                                        ReportDtos.CategoryPerformance cp = new ReportDtos.CategoryPerformance();
                                        cp.setCategoryId(cat.getId());
                                        cp.setCategoryNameEn(cat.getNameEn());
                                        cp.setCategoryNameKm(cat.getNameKm());
                                        cp.setTotal(total);
                                        cp.setQuantity(qty);
                                        return cp;
                                }).sorted(Comparator.comparing(ReportDtos.CategoryPerformance::getTotal).reversed())
                                .collect(Collectors.toList());
                return paginate(rows, page, size);
        }

        public Page<ReportDtos.CashierPerformance> cashierPerformance(
                        LocalDate from,
                        LocalDate to,
                        Integer fromHour,
                        Integer toHour,
                        Long employeeId,
                        int page,
                        int size) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }
                List<Sale> sales = filterSalesByInvoiceDateRange(from, to).stream()
                                .filter(sale -> matchesHourRange(sale, fromHour, toHour))
                                .filter(sale -> matchesEmployee(sale, employeeId))
                                .toList();

                Map<Long, List<Sale>> byCashier = sales.stream()
                                .filter(s -> s.getCreatedBy() != null)
                                .collect(Collectors.groupingBy(s -> s.getCreatedBy().getId()));

                List<ReportDtos.CashierPerformance> rows = byCashier.values().stream().map(list -> {
                        var user = list.get(0).getCreatedBy();
                        BigDecimal total = list.stream().map(Sale::getGrandTotal).reduce(BigDecimal.ZERO,
                                        BigDecimal::add);
                        ReportDtos.CashierPerformance perf = new ReportDtos.CashierPerformance();
                        perf.setCashierId(user.getId());
                        perf.setCashierName(user.getFullName());
                        perf.setSalesTotal(total);
                        perf.setSalesCount(list.size());
                        return perf;
                }).sorted(Comparator.comparing(ReportDtos.CashierPerformance::getSalesTotal).reversed())
                                .collect(Collectors.toList());

                return paginate(rows, page, size);
        }

        public Page<ReportDtos.SalesByItemRow> salesByItemReport(
                        LocalDate from,
                        LocalDate to,
                        Integer fromHour,
                        Integer toHour,
                        Long employeeId,
                        int page,
                        int size,
                        String sort) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }
                List<Sale> filtered = filterSalesByInvoiceDateRange(from, to).stream()
                                .filter(sale -> matchesHourRange(sale, fromHour, toHour))
                                .filter(sale -> matchesEmployee(sale, employeeId))
                                .toList();

                Map<Long, List<SaleLine>> byProduct = filtered.stream()
                                .flatMap(s -> s.getLines().stream())
                                .collect(Collectors.groupingBy(sl -> sl.getProduct().getId()));

                List<ReportDtos.SalesByItemRow> rows = byProduct.values().stream().map(lineList -> {
                        var product = lineList.get(0).getProduct();
                        BigDecimal qty = lineList.stream().map(SaleLine::getQuantity)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        BigDecimal gross = lineList.stream()
                                        .map(line -> safe(line.getUnitPrice()).multiply(safe(line.getQuantity())))
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        BigDecimal discount = lineList.stream().map(SaleLine::getLineDiscount).map(this::safe)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        BigDecimal net = lineList.stream().map(SaleLine::getLineTotal).map(this::safe)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        ReportDtos.SalesByItemRow row = new ReportDtos.SalesByItemRow();
                        row.setProductId(product.getId());
                        row.setNameEn(product.getNameEn());
                        row.setNameKm(product.getNameKm());
                        row.setSku(product.getSku());
                        row.setQuantitySold(qty);
                        row.setGrossSales(gross);
                        row.setDiscount(discount);
                        row.setNetSales(net);
                        return row;
                }).collect(Collectors.toList());

                Comparator<ReportDtos.SalesByItemRow> comparator = "quantity".equalsIgnoreCase(sort)
                                ? Comparator.comparing(ReportDtos.SalesByItemRow::getQuantitySold)
                                : Comparator.comparing(ReportDtos.SalesByItemRow::getNetSales);
                rows = rows.stream().sorted(comparator.reversed()).collect(Collectors.toList());

                return paginate(rows, page, size);
        }

        public Page<ReportDtos.ModifierPerformance> salesByModifierReport(
                        LocalDate from,
                        LocalDate to,
                        Integer fromHour,
                        Integer toHour,
                        Long employeeId,
                        int page,
                        int size) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }
                List<Sale> sales = filterSalesByInvoiceDateRange(from, to).stream()
                                .filter(sale -> matchesHourRange(sale, fromHour, toHour))
                                .filter(sale -> matchesEmployee(sale, employeeId))
                                .toList();

                Map<String, ReportDtos.ModifierPerformance> byOption = new LinkedHashMap<>();
                for (Sale sale : sales) {
                        if (sale.getLines() == null) {
                                continue;
                        }
                        for (SaleLine line : sale.getLines()) {
                                String json = line.getModifierData();
                                if (json == null || json.isBlank()) {
                                        continue;
                                }
                                ModifierSelectionJson[] selections;
                                try {
                                        selections = MODIFIER_JSON_MAPPER.readValue(json, ModifierSelectionJson[].class);
                                } catch (Exception ex) {
                                        // Malformed/unparseable modifierData - skip this line rather than failing the report.
                                        continue;
                                }
                                if (selections == null) {
                                        continue;
                                }
                                BigDecimal qty = safe(line.getQuantity());
                                for (ModifierSelectionJson selection : selections) {
                                        if (selection == null) {
                                                continue;
                                        }
                                        String optionName = selection.optionName == null || selection.optionName.isBlank()
                                                        ? "Unknown"
                                                        : selection.optionName;
                                        ReportDtos.ModifierPerformance perf = byOption.computeIfAbsent(optionName, key -> {
                                                ReportDtos.ModifierPerformance created = new ReportDtos.ModifierPerformance();
                                                created.setGroupName(selection.groupName);
                                                created.setOptionName(optionName);
                                                created.setQuantity(BigDecimal.ZERO);
                                                created.setRevenue(BigDecimal.ZERO);
                                                return created;
                                        });
                                        BigDecimal priceDelta = safe(selection.priceDelta);
                                        perf.setQuantity(perf.getQuantity().add(qty));
                                        perf.setRevenue(perf.getRevenue().add(priceDelta.multiply(qty)));
                                }
                        }
                }

                List<ReportDtos.ModifierPerformance> rows = byOption.values().stream()
                                .sorted(Comparator.comparing(ReportDtos.ModifierPerformance::getRevenue).reversed())
                                .collect(Collectors.toList());

                return paginate(rows, page, size);
        }

        public ReportDtos.DiscountReportResponse discounts(
                        LocalDate from,
                        LocalDate to,
                        Integer fromHour,
                        Integer toHour,
                        Long employeeId,
                        int page,
                        int size) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }
                List<Sale> sales = filterSalesByInvoiceDateRange(from, to).stream()
                                .filter(sale -> matchesHourRange(sale, fromHour, toHour))
                                .filter(sale -> matchesEmployee(sale, employeeId))
                                .toList();

                List<ReportDtos.DiscountRow> rows = sales.stream()
                                .flatMap(sale -> discountRowsForSale(sale).stream())
                                .sorted(Comparator.comparing(ReportDtos.DiscountRow::getDate).reversed())
                                .collect(Collectors.toList());

                ReportDtos.DiscountTotals totals = new ReportDtos.DiscountTotals();
                totals.setCount(rows.size());
                totals.setTotalAmount(rows.stream()
                                .map(ReportDtos.DiscountRow::getAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));

                ReportDtos.DiscountReportResponse response = new ReportDtos.DiscountReportResponse();
                response.setFromDate(from);
                response.setToDate(to);
                response.setRows(paginate(rows, page, size));
                response.setTotals(totals);
                return response;
        }

        private List<ReportDtos.DiscountRow> discountRowsForSale(Sale sale) {
                if (sale.getDiscounts() == null || sale.getDiscounts().isEmpty()) {
                        return List.of();
                }
                return sale.getDiscounts().stream()
                                .map(discount -> toDiscountRow(sale, discount))
                                .toList();
        }

        private ReportDtos.DiscountRow toDiscountRow(Sale sale, SaleDiscount discount) {
                ReportDtos.DiscountRow row = new ReportDtos.DiscountRow();
                row.setSaleId(sale.getId());
                row.setSaleNumber(reportDocumentNumber(sale));
                row.setDate(resolveSaleInvoiceDate(sale));
                row.setEmployeeName(sale.getCreatedBy() != null ? sale.getCreatedBy().getFullName() : "Unknown");
                row.setDiscountType(discount.getDiscountType());
                row.setAmount(safe(discount.getAmount()));
                row.setReason(discount.getReason());
                return row;
        }

        public ReportDtos.TaxRangeReportResponse taxRangeReport(
                        LocalDate from,
                        LocalDate to,
                        Integer fromHour,
                        Integer toHour,
                        Long employeeId,
                        int page,
                        int size) {
                if (from == null || to == null) {
                        throw new ApiException("From and to dates are required");
                }
                if (to.isBefore(from)) {
                        throw new ApiException("Date To cannot be earlier than Date From");
                }
                List<Sale> sales = filterSalesByInvoiceDateRange(from, to).stream()
                                .filter(sale -> matchesHourRange(sale, fromHour, toHour))
                                .filter(sale -> matchesEmployee(sale, employeeId))
                                .toList();

                Map<LocalDate, List<Sale>> byDate = sales.stream()
                                .collect(Collectors.groupingBy(
                                                this::resolveSaleInvoiceDate,
                                                LinkedHashMap::new,
                                                Collectors.toList()));

                List<ReportDtos.TaxReportRow> rows = byDate.entrySet().stream()
                                .sorted(Map.Entry.comparingByKey())
                                .map(entry -> {
                                        List<Sale> daySales = entry.getValue();
                                        ReportDtos.TaxReportRow row = new ReportDtos.TaxReportRow();
                                        row.setDate(entry.getKey());
                                        // Taxable sales follow the same "taxable = subtotal - discount" convention
                                        // SaleService uses when computing taxAmount at checkout.
                                        row.setTaxableSales(daySales.stream()
                                                        .map(sale -> safe(sale.getSubtotal()).subtract(safe(sale.getDiscountAmount())))
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        row.setTaxCollected(daySales.stream()
                                                        .map(Sale::getTaxAmount)
                                                        .map(this::safe)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        row.setSalesCount(daySales.size());
                                        return row;
                                }).collect(Collectors.toList());

                BigDecimal totalTax = sales.stream().map(Sale::getTaxAmount).map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);

                ReportDtos.TaxRangeReportResponse response = new ReportDtos.TaxRangeReportResponse();
                response.setFromDate(from);
                response.setToDate(to);
                response.setRows(paginate(rows, page, size));
                response.setTotalTaxCollected(totalTax);
                return response;
        }

        @Transactional(readOnly = true)
        public byte[] dailyZReportPdf(LocalDate date) {
                ReportDtos.DailyZReport report = dailyZReport(date);
                String html = generateZReportHtml(report);
                return pdfService.renderHtmlToPdf(html);
        }

        @Transactional(readOnly = true)
        public ReportDtos.DailyZReport dailyZReport(LocalDate date) {
                var start = date.atStartOfDay().toInstant(ZoneOffset.UTC);
                var end = date.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);
                List<Sale> sales = filterSalesByRange(start, end);

                ReportDtos.DailyZReport report = new ReportDtos.DailyZReport();
                report.setDate(date.toString());
                report.setTransactionCount(sales.size());

                BigDecimal totalSales = sales.stream().map(Sale::getGrandTotal).reduce(BigDecimal.ZERO,
                                BigDecimal::add);
                report.setTotalSales(totalSales);

                Map<String, BigDecimal> methodTotals = sales.stream()
                                .flatMap(s -> s.getPayments() == null ? java.util.stream.Stream.empty()
                                                : s.getPayments().stream())
                                .collect(Collectors.groupingBy(Payment::getMethod,
                                                Collectors.reducing(BigDecimal.ZERO, Payment::getAmount,
                                                                BigDecimal::add)));
                report.setPaymentMethodBreakdown(methodTotals);

                Map<Long, List<SaleLine>> byProduct = sales.stream()
                                .flatMap(s -> s.getLines() == null ? java.util.stream.Stream.empty()
                                                : s.getLines().stream())
                                .collect(Collectors.groupingBy(sl -> sl.getProduct().getId()));

                List<ReportDtos.TopProduct> topProducts = byProduct.entrySet().stream().map(entry -> {
                        var lineList = entry.getValue();
                        var product = lineList.get(0).getProduct();
                        BigDecimal qty = lineList.stream().map(SaleLine::getQuantity).reduce(BigDecimal.ZERO,
                                        BigDecimal::add);
                        BigDecimal total = lineList.stream().map(SaleLine::getLineTotal).reduce(BigDecimal.ZERO,
                                        BigDecimal::add);
                        ReportDtos.TopProduct tp = new ReportDtos.TopProduct();
                        tp.setProductId(product.getId());
                        tp.setNameEn(product.getNameEn());
                        tp.setNameKm(product.getNameKm());
                        tp.setQuantity(qty);
                        tp.setTotal(total);
                        return tp;
                }).sorted(Comparator.comparing(ReportDtos.TopProduct::getTotal).reversed()).limit(10)
                                .collect(Collectors.toList());
                report.setTopProducts(topProducts);

                report.setShifts(shiftSummariesByRange(start, end));

                return report;
        }

        public String generateZReportHtml(ReportDtos.DailyZReport report) {
                var settings = businessSettingsRepository.findAll().stream().findFirst().orElse(null);

                StringBuilder html = new StringBuilder();
                html.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/>")
                                .append("<style>")
                                .append("body { font-family: Arial, sans-serif; font-size: 12px; max-width: 800px; margin: 0 auto; padding: 20px; }")
                                .append(".header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 10px; margin-bottom: 20px; }")
                                .append(".title { font-size: 20px; font-weight: bold; }")
                                .append(".section { margin: 20px 0; }")
                                .append(".section-title { font-size: 14px; font-weight: bold; background: #f0f0f0; padding: 5px; margin-bottom: 10px; }")
                                .append("table { width: 100%; border-collapse: collapse; }")
                                .append("th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }")
                                .append("th { background: #f8f8f8; }")
                                .append(".text-right { text-align: right; }")
                                .append(".total-row { font-weight: bold; background: #f0f0f0; }")
                                .append("</style></head><body>");

                html.append("<div class='header'>")
                                .append("<div class='title'>DAILY Z-REPORT</div>");
                if (settings != null) {
                        html.append("<div>").append(settings.getBusinessName()).append("</div>")
                                        .append("<div>").append(settings.getAddress()).append("</div>")
                                        .append("<div>").append(settings.getPhone()).append("</div>");
                }
                html.append("<div>Report Date: ").append(report.getDate()).append("</div>")
                                .append("<div>Generated: ").append(java.time.LocalDateTime.now()).append("</div>")
                                .append("</div>");

                html.append("<div class='section'>")
                                .append("<div class='section-title'>SALES SUMMARY</div>")
                                .append("<table>")
                                .append("<tr><th>Metric</th><th class='text-right'>Value</th></tr>")
                                .append("<tr><td>Total Transactions</td><td class='text-right'>")
                                .append(report.getTransactionCount()).append("</td></tr>")
                                .append("<tr class='total-row'><td>TOTAL SALES</td><td class='text-right'>៛")
                                .append(String.format("%,.2f", report.getTotalSales())).append("</td></tr>")
                                .append("</table>")
                                .append("</div>");

                Map<String, BigDecimal> paymentBreakdown = report.getPaymentMethodBreakdown() != null
                                ? report.getPaymentMethodBreakdown()
                                : java.util.Collections.emptyMap();

                html.append("<div class='section'>")
                                .append("<div class='section-title'>PAYMENT METHOD BREAKDOWN</div>")
                                .append("<table>")
                                .append("<tr><th>Method</th><th class='text-right'>Amount</th></tr>");
                paymentBreakdown.forEach((method, total) -> {
                        html.append("<tr><td>").append(method).append("</td><td class='text-right'>៛")
                                        .append(String.format("%,.2f", total)).append("</td></tr>");
                });
                html.append("</table></div>");

                html.append("<div class='section'>")
                                .append("<div class='section-title'>SHIFT SUMMARY</div>")
                                .append("<table>")
                                .append("<tr><th>Shift ID</th><th>Opened By</th><th>Status</th><th class='text-right'>Variance</th></tr>");
                report.getShifts().forEach(shift -> {
                        html.append("<tr><td>").append(shift.getShiftId()).append("</td>")
                                        .append("<td>").append(shift.getOpenedBy() != null ? shift.getOpenedBy() : "-")
                                        .append("</td>")
                                        .append("<td>").append(shift.getStatus()).append("</td>")
                                        .append("<td class='text-right'>")
                                        .append(shift.getVariance() != null
                                                        ? String.format("៛%,.2f", shift.getVariance())
                                                        : "-")
                                        .append("</td></tr>");
                });
                html.append("</table></div>");

                html.append("</body></html>");
                return html.toString();
        }

        private List<Sale> filterSalesByRange(java.time.Instant start, java.time.Instant end) {
                return saleRepository.findReportSalesByCreatedAt(start, end, REPORT_STATUSES);
        }

        private List<Sale> filterSalesByInvoiceDateRange(LocalDate from, LocalDate to) {
                return saleRepository.findReportSalesByInvoiceDate(
                                from,
                                to,
                                from.atStartOfDay().toInstant(ZoneOffset.UTC),
                                to.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC),
                                REPORT_STATUSES);
        }

        /**
         * Hour-of-day filter shared by the range-based reports. When both bounds are null, no
         * filtering is applied. Hours are evaluated in {@link #REPORT_ZONE} so the "hour" a sale
         * happened in matches what a cashier in that timezone would expect.
         */
        private boolean matchesHourRange(Sale sale, Integer fromHour, Integer toHour) {
                if (fromHour == null && toHour == null) {
                        return true;
                }
                if (sale.getCreatedAt() == null) {
                        return false;
                }
                int hour = sale.getCreatedAt().atZone(REPORT_ZONE).getHour();
                if (fromHour != null && hour < fromHour) {
                        return false;
                }
                if (toHour != null && hour > toHour) {
                        return false;
                }
                return true;
        }

        /**
         * employeeId filters against {@link Sale#getCreatedBy()} - the cashier who rang up the
         * sale. Same identity already used by cashierId on /sales and /sales-summary.
         */
        private boolean matchesEmployee(Sale sale, Long employeeId) {
                return employeeId == null
                                || (sale.getCreatedBy() != null && employeeId.equals(sale.getCreatedBy().getId()));
        }

        /**
         * Manual pagination over an already-computed in-memory list. Mirrors the Page JSON shape
         * (content/totalElements/totalPages/number/size) used by repository-backed Page<T>
         * endpoints elsewhere in the app (e.g. ProductController.search).
         */
        private <T> Page<T> paginate(List<T> items, int page, int size) {
                int safePage = Math.max(0, page);
                int safeSize = Math.min(Math.max(1, size), 200);
                int total = items.size();
                int fromIndex = Math.min(safePage * safeSize, total);
                int toIndex = Math.min(fromIndex + safeSize, total);
                List<T> content = items.subList(fromIndex, toIndex);
                return new PageImpl<>(content, PageRequest.of(safePage, safeSize), total);
        }

        /** Mirrors the write-side JSON shape produced at checkout for SaleLine.modifierData. */
        private static class ModifierSelectionJson {
                public Long groupId;
                public String groupName;
                public Long optionId;
                public String optionName;
                public BigDecimal priceDelta;
        }

        private LocalDate resolveSaleInvoiceDate(Sale sale) {
                if (sale.getOrderDate() != null) {
                        return sale.getOrderDate();
                }
                if (sale.getCreatedAt() != null) {
                        return sale.getCreatedAt().atZone(REPORT_ZONE).toLocalDate();
                }
                return LocalDate.now(REPORT_ZONE);
        }

        private LocalDate resolvePurchaseOrderDate(com.kaknnea.pos.domain.PurchaseOrder order) {
                if (order.getOrderedAt() != null) {
                        return order.getOrderedAt().atZone(ZoneOffset.UTC).toLocalDate();
                }
                if (order.getCreatedAt() != null) {
                        return order.getCreatedAt().atZone(ZoneOffset.UTC).toLocalDate();
                }
                return LocalDate.now(ZoneOffset.UTC);
        }

        private LocalDate resolveGoodsReceiptDate(GoodsReceipt receipt) {
                if (receipt.getReceivedAt() != null) {
                        return receipt.getReceivedAt().atZone(ZoneOffset.UTC).toLocalDate();
                }
                if (receipt.getCreatedAt() != null) {
                        return receipt.getCreatedAt().atZone(ZoneOffset.UTC).toLocalDate();
                }
                return LocalDate.now(ZoneOffset.UTC);
        }

        private boolean matchesRange(LocalDate date, LocalDate from, LocalDate to) {
                return date != null && !date.isBefore(from) && !date.isAfter(to);
        }

        private boolean matchesStore(com.kaknnea.pos.domain.Store store, Long storeId) {
                return store != null && storeId.equals(store.getId());
        }

        private boolean matchesMethod(String actualMethod, String selectedMethod) {
                if (selectedMethod == null) {
                        return true;
                }
                return selectedMethod.equalsIgnoreCase(actualMethod);
        }

        private boolean matchesDirection(String actualDirection, String selectedDirection) {
                return selectedDirection == null
                                || "ALL".equalsIgnoreCase(selectedDirection)
                                || selectedDirection.equalsIgnoreCase(actualDirection);
        }

        private LocalDate resolvePaymentDate(Payment payment) {
                if (payment.getCreatedAt() != null) {
                        return payment.getCreatedAt().atZone(ZoneOffset.UTC).toLocalDate();
                }
                return LocalDate.now(ZoneOffset.UTC);
        }

        private LocalDate resolveSupplierPaymentDate(com.kaknnea.pos.domain.SupplierPayment payment) {
                if (payment.getPaidAt() != null) {
                        return payment.getPaidAt().atZone(ZoneOffset.UTC).toLocalDate();
                }
                if (payment.getCreatedAt() != null) {
                        return payment.getCreatedAt().atZone(ZoneOffset.UTC).toLocalDate();
                }
                return LocalDate.now(ZoneOffset.UTC);
        }

        private com.kaknnea.pos.domain.Store resolvePaymentStore(Payment payment) {
                com.kaknnea.pos.domain.Store directStore = safelyResolve(payment::getStore);
                if (directStore != null) {
                        return directStore;
                }
                Sale sale = safelyResolve(payment::getSale);
                if (sale != null && safelyResolve(sale::getShift) != null) {
                        return safelyResolve(() -> sale.getShift().getStore());
                }
                com.kaknnea.pos.domain.Shift shift = safelyResolve(payment::getShift);
                if (shift != null) {
                        return safelyResolve(shift::getStore);
                }
                return null;
        }

        private com.kaknnea.pos.domain.Store resolveSupplierPaymentStore(com.kaknnea.pos.domain.SupplierPayment payment) {
                if (payment.getSupplierInvoice() != null) {
                        return payment.getSupplierInvoice().getStore();
                }
                return null;
        }

        private String resolveCustomerPaymentMethod(Payment payment) {
                if (payment.getMethod() != null && !payment.getMethod().isBlank()) {
                        return payment.getMethod().trim().toUpperCase();
                }
                if (payment.getPaymentMethod() != null) {
                        return payment.getPaymentMethod().name();
                }
                return "CASH";
        }

        private String resolveSupplierPaymentMethod(com.kaknnea.pos.domain.SupplierPayment payment) {
                if (payment.getPaymentMethod() != null && !payment.getPaymentMethod().isBlank()) {
                        return payment.getPaymentMethod().trim().toUpperCase();
                }
                return "CASH";
        }

        private String normalizeFilter(String value) {
                if (value == null || value.isBlank() || "ALL".equalsIgnoreCase(value)) {
                        return null;
                }
                return value.trim().toUpperCase();
        }

        private String normalizeDirection(String value) {
                if (value == null || value.isBlank() || "ALL".equalsIgnoreCase(value)) {
                        return "ALL";
                }
                return value.trim().toUpperCase();
        }

        private ReportDtos.PaymentMovementRow toIncomingPaymentRow(Payment payment) {
                ReportDtos.PaymentMovementRow row = new ReportDtos.PaymentMovementRow();
                Sale sale = safelyResolve(payment::getSale);
                Customer paymentCustomer = safelyResolve(payment::getCustomer);
                Customer saleCustomer = sale != null ? safelyResolve(sale::getCustomer) : null;
                com.kaknnea.pos.domain.Store store = resolvePaymentStore(payment);
                row.setDate(resolvePaymentDate(payment));
                row.setDirection("IN");
                row.setSourceType("SALE");
                row.setSaleId(sale != null ? sale.getId() : null);
                row.setCustomerId(paymentCustomer != null ? paymentCustomer.getId() : (saleCustomer != null ? saleCustomer.getId() : null));
                row.setDocumentNumber(sale != null ? DocumentNumberUtil.saleNumber(sale) : null);
                row.setReferenceNumber(firstNonBlank(DocumentNumberUtil.paymentReference(payment), payment.getTransactionId()));
                row.setCounterpartyName(resolvePaymentCounterparty(payment));
                row.setStoreId(store != null ? store.getId() : null);
                row.setStoreName(store != null ? store.getName() : null);
                row.setPaymentMethod(resolveCustomerPaymentMethod(payment));
                row.setAmount(safe(payment.getAmount()));
                return row;
        }

        private boolean matchesPaymentCustomer(Payment payment, Long customerId) {
                Customer paymentCustomer = safelyResolve(payment::getCustomer);
                if (paymentCustomer != null && customerId.equals(paymentCustomer.getId())) {
                        return true;
                }
                Sale sale = safelyResolve(payment::getSale);
                Customer saleCustomer = sale != null ? safelyResolve(sale::getCustomer) : null;
                return saleCustomer != null && customerId.equals(saleCustomer.getId());
        }

        private ReportDtos.PaymentMovementRow toOutgoingPaymentRow(com.kaknnea.pos.domain.SupplierPayment payment) {
                ReportDtos.PaymentMovementRow row = new ReportDtos.PaymentMovementRow();
                var supplier = payment.getSupplierInvoice() != null ? payment.getSupplierInvoice().getSupplier() : null;
                row.setDate(resolveSupplierPaymentDate(payment));
                row.setDirection("OUT");
                row.setSourceType("SUPPLIER_BILL");
                row.setDocumentNumber(payment.getSupplierInvoice() != null ? payment.getSupplierInvoice().getInvoiceNumber() : null);
                row.setReferenceNumber(payment.getReference());
                row.setSupplierId(supplier != null ? supplier.getId() : null);
                row.setCounterpartyName(supplier != null ? supplier.getName() : null);
                row.setStoreId(resolveSupplierPaymentStore(payment) != null ? resolveSupplierPaymentStore(payment).getId() : null);
                row.setStoreName(resolveSupplierPaymentStore(payment) != null ? resolveSupplierPaymentStore(payment).getName() : null);
                row.setPaymentMethod(resolveSupplierPaymentMethod(payment));
                row.setAmount(safe(payment.getAmount()));
                return row;
        }

        private boolean matchesSupplierPaymentSupplier(com.kaknnea.pos.domain.SupplierPayment payment, Long supplierId) {
                return payment.getSupplierInvoice() != null
                                && payment.getSupplierInvoice().getSupplier() != null
                                && supplierId.equals(payment.getSupplierInvoice().getSupplier().getId());
        }

        private String resolvePaymentCounterparty(Payment payment) {
                Customer paymentCustomer = safelyResolve(payment::getCustomer);
                if (paymentCustomer != null) {
                        String customerName = resolveCustomerName(paymentCustomer);
                        if (customerName != null) {
                                return customerName;
                        }
                }
                Sale sale = safelyResolve(payment::getSale);
                Customer saleCustomer = sale != null ? safelyResolve(sale::getCustomer) : null;
                if (saleCustomer != null) {
                        return resolveCustomerName(saleCustomer);
                }
                return null;
        }

        private String resolveCustomerName(Customer customer) {
                if (customer == null) {
                        return null;
                }
                try {
                        return firstNonBlank(
                                        firstNonBlank(customer.getDisplayName(), customer.getNameEn()),
                                        firstNonBlank(customer.getNameKm(), customer.getContactPerson()));
                } catch (EntityNotFoundException | org.hibernate.ObjectNotFoundException ex) {
                        return null;
                }
        }

        private <T> T safelyResolve(Supplier<T> supplier) {
                try {
                        return supplier.get();
                } catch (EntityNotFoundException | org.hibernate.ObjectNotFoundException ex) {
                        return null;
                }
        }

        private ReportDtos.ExpenseReportRow toExpenseReportRow(Expense expense) {
                ReportDtos.ExpenseReportRow row = new ReportDtos.ExpenseReportRow();
                row.setDate(expense.getExpenseDate());
                row.setExpenseNumber(expense.getExpenseNumber());
                row.setCategoryId(expense.getCategory() != null ? expense.getCategory().getId() : null);
                row.setCategoryNameEn(expense.getCategory() != null ? expense.getCategory().getNameEn() : null);
                row.setCategoryNameKm(expense.getCategory() != null ? expense.getCategory().getNameKm() : null);
                row.setDescription(expense.getDescription());
                row.setStatus(expense.getStatus());
                row.setPaymentMethod(expense.getPaymentMethod());
                row.setReference(expense.getReference());
                row.setApprovedByName(expense.getApprovedBy() != null ? expense.getApprovedBy().getFullName() : null);
                row.setAmount(safe(expense.getAmount()));
                return row;
        }

        private String firstNonBlank(String left, String right) {
                if (left != null && !left.isBlank()) {
                        return left;
                }
                return right;
        }

        private String reportDocumentNumber(Sale sale) {
                String displayName = trimToNull(sale.getDisplayName());
                if (displayName != null) {
                        return displayName;
                }
                return DocumentNumberUtil.saleNumber(sale);
        }

        private String trimToNull(String value) {
                if (value == null) {
                        return null;
                }
                String trimmed = value.trim();
                return trimmed.isEmpty() ? null : trimmed;
        }

        private String safeText(String value) {
                return value == null ? "" : value;
        }

        private ReportDtos.PurchaseSummaryRow emptyPurchaseSummaryRow(LocalDate date) {
                ReportDtos.PurchaseSummaryRow row = new ReportDtos.PurchaseSummaryRow();
                row.setDate(date);
                row.setOrderedValue(BigDecimal.ZERO);
                row.setReceivedValue(BigDecimal.ZERO);
                row.setBilledValue(BigDecimal.ZERO);
                row.setPaidValue(BigDecimal.ZERO);
                row.setOutstandingValue(BigDecimal.ZERO);
                return row;
        }

        private BigDecimal safe(BigDecimal value) {
                return value == null ? BigDecimal.ZERO : value;
        }

        private BigDecimal sumPurchaseOrderAmounts(List<com.kaknnea.pos.domain.PurchaseOrder> purchaseOrders) {
                return purchaseOrders.stream()
                                .map(com.kaknnea.pos.domain.PurchaseOrder::getTotalAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);
        }

        private BigDecimal sumGoodsReceiptAmounts(List<GoodsReceipt> goodsReceipts) {
                return goodsReceipts.stream()
                                .map(GoodsReceipt::getTotalAmount)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);
        }

        private BigDecimal sumSupplierInvoiceField(
                        List<com.kaknnea.pos.domain.SupplierInvoice> supplierInvoices,
                        java.util.function.Function<com.kaknnea.pos.domain.SupplierInvoice, BigDecimal> mapper) {
                return supplierInvoices.stream()
                                .map(mapper)
                                .map(this::safe)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);
        }

        private long distinctSupplierCount(
                        List<com.kaknnea.pos.domain.PurchaseOrder> purchaseOrders,
                        List<GoodsReceipt> goodsReceipts,
                        List<com.kaknnea.pos.domain.SupplierInvoice> supplierInvoices) {
                return java.util.stream.Stream.concat(
                                purchaseOrders.stream().map(com.kaknnea.pos.domain.PurchaseOrder::getSupplier),
                                java.util.stream.Stream.concat(
                                                goodsReceipts.stream().map(GoodsReceipt::getSupplier),
                                                supplierInvoices.stream().map(com.kaknnea.pos.domain.SupplierInvoice::getSupplier)))
                                .filter(java.util.Objects::nonNull)
                                .map(supplier -> supplier.getId())
                                .distinct()
                                .count();
        }

        private List<ReportDtos.ShiftSummary> shiftSummariesByRange(java.time.Instant start, java.time.Instant end) {
                var shifts = shiftRepository.findByOpenedAtGreaterThanEqualAndOpenedAtLessThanOrderByOpenedAtAsc(start, end);

                return shifts.stream().map(shift -> {
                        ReportDtos.ShiftSummary summary = new ReportDtos.ShiftSummary();
                        summary.setShiftId(shift.getId());
                        summary.setOpenedBy(shift.getOpenedBy() != null ? shift.getOpenedBy().getFullName() : null);
                        summary.setOpenedAt(shift.getOpenedAt());
                        summary.setClosedAt(shift.getClosedAt());
                        summary.setOpeningCash(shift.getOpeningCash());
                        summary.setClosingCash(shift.getClosingCash());
                        summary.setExpectedCash(shift.getExpectedCash());
                        summary.setVariance(shift.getVariance());
                        summary.setStatus(shift.getStatus());
                        if (shift.getId() != null) {
                                var view = saleRepository.salesByShift(shift.getId());
                                if (view != null) {
                                        summary.setSalesTotal(view.getTotal());
                                        summary.setSalesCount(view.getCount());
                                }
                        }
                        return summary;
                }).collect(Collectors.toList());
        }

        public List<ReportDtos.StockMovementRow> stockMovements(LocalDate from, LocalDate to) {
                var start = from.atStartOfDay().toInstant(ZoneOffset.UTC);
                var end = to.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);
                return stockMovementRepository.findByCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(start, end).stream()
                                .map(m -> {
                                        ReportDtos.StockMovementRow row = new ReportDtos.StockMovementRow();
                                        row.setProductId(m.getProduct().getId());
                                        row.setProductNameEn(m.getProduct().getNameEn());
                                        row.setMovementType(m.getMovementType());
                                        row.setQuantity(m.getQuantity());
                                        row.setStoreId(m.getStore().getId());
                                        row.setCreatedAt(m.getCreatedAt().toString());
                                        return row;
                                }).collect(Collectors.toList());
        }

        public List<ReportDtos.AuditTrailRow> auditTrailReport(LocalDate from, LocalDate to) {
                return auditLogsInRange(from, to).stream()
                                .map(this::toAuditTrailRow)
                                .collect(Collectors.toList());
        }

        public List<ReportDtos.AuditTrailRow> auditCategoryReport(String category, LocalDate from, LocalDate to) {
                return auditLogsInRange(from, to).stream()
                                .filter(log -> auditCategoryMatches(category, log))
                                .map(this::toAuditTrailRow)
                                .collect(Collectors.toList());
        }

        public List<ReportDtos.LoginHistoryRow> loginHistoryReport(LocalDate from, LocalDate to) {
                var start = reportStart(from);
                var end = reportEnd(to);
                return loginAuditRepository.findTop500ByCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(start, end).stream()
                                .map(this::toLoginHistoryRow)
                                .collect(Collectors.toList());
        }

        public List<ReportDtos.StockAdjustmentAuditRow> stockAdjustmentAuditReport(LocalDate from, LocalDate to) {
                var start = reportStart(from);
                var end = reportEnd(to);
                return stockMovementRepository.findAdjustmentAuditMovements(start, end).stream()
                                .map(this::toStockAdjustmentRow)
                                .collect(Collectors.toList());
        }

        public List<ReportDtos.StockCountVarianceRow> stockCountVarianceReport(LocalDate from, LocalDate to) {
                List<ReportDtos.StockCountVarianceRow> varianceRows = inventorySnapshotRepository.findTop500BySnapshotDateBetweenOrderByCreatedAtDesc(from, to).stream()
                                .filter(snapshot -> snapshot.getCountedQuantity() != null
                                                || snapshot.getVarianceQuantity() != null)
                                .map(this::toStockCountVarianceRow)
                                .collect(Collectors.toList());
                if (!varianceRows.isEmpty()) {
                        return varianceRows;
                }
                return stockItemRepository.findStockCountFallbackRows(PageRequest.of(0, 500)).stream()
                                .map(this::toUncountedStockCountRow)
                                .collect(Collectors.toList());
        }

        public List<ReportDtos.CashAdjustmentRow> cashAdjustmentReport(LocalDate from, LocalDate to) {
                var start = reportStart(from);
                var end = reportEnd(to);
                return shiftRepository.findCashAdjustmentShifts(start, end).stream()
                                .map(this::toCashAdjustmentRow)
                                .collect(Collectors.toList());
        }

        private List<AuditLog> auditLogsInRange(LocalDate from, LocalDate to) {
                var start = reportStart(from);
                var end = reportEnd(to);
                return auditLogRepository.findTop500ByCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(start, end);
        }

        private ReportDtos.AuditTrailRow toAuditTrailRow(AuditLog log) {
                ReportDtos.AuditTrailRow row = new ReportDtos.AuditTrailRow();
                row.setDateTime(log.getCreatedAt());
                row.setUser(actorName(log));
                row.setEntity(log.getEntity());
                row.setEntityId(log.getEntityId());
                row.setModule(moduleLabel(log));
                row.setAction(humanize(log.getAction()));
                row.setReference(referenceLabel(log));
                row.setBeforeJson(log.getBeforeJson());
                row.setAfterJson(log.getAfterJson());
                return row;
        }

        private ReportDtos.LoginHistoryRow toLoginHistoryRow(LoginAudit audit) {
                ReportDtos.LoginHistoryRow row = new ReportDtos.LoginHistoryRow();
                row.setEmail(audit.getEmail());
                row.setUser(audit.getUser() != null ? audit.getUser().getFullName() : audit.getEmail());
                row.setIpAddress(audit.getIpAddress());
                row.setDevice(deviceLabel(audit.getUserAgent()));
                row.setBrowser(browserLabel(audit.getUserAgent()));
                row.setLoginTime(audit.getCreatedAt());
                row.setLogoutTime(null);
                row.setStatus(audit.isSuccess() ? "Success" : "Failed");
                return row;
        }

        private ReportDtos.StockAdjustmentAuditRow toStockAdjustmentRow(StockMovement movement) {
                ReportDtos.StockAdjustmentAuditRow row = new ReportDtos.StockAdjustmentAuditRow();
                row.setAdjustmentNo("ADJ-" + String.format("%05d", movement.getId() == null ? 0 : movement.getId()));
                row.setProduct(movement.getProduct() != null ? movement.getProduct().getNameEn() : "-");
                row.setOldQty(null);
                row.setNewQty(null);
                row.setDifference(movement.getQuantity());
                row.setReason(movement.getReason());
                row.setCreatedBy(movement.getCreatedBy());
                row.setDateTime(movement.getCreatedAt());
                return row;
        }

        private ReportDtos.StockCountVarianceRow toStockCountVarianceRow(InventorySnapshot snapshot) {
                ReportDtos.StockCountVarianceRow row = new ReportDtos.StockCountVarianceRow();
                row.setProduct(snapshot.getProduct() != null ? snapshot.getProduct().getNameEn() : "-");
                row.setStore(snapshot.getStore() != null ? snapshot.getStore().getName() : "-");
                row.setDate(snapshot.getSnapshotDate());
                row.setSystemQty(snapshot.getQuantity());
                row.setCountedQty(snapshot.getCountedQuantity());
                row.setVariance(snapshot.getVarianceQuantity());
                row.setStatus(snapshot.getCountStatus());
                return row;
        }

        private ReportDtos.StockCountVarianceRow toUncountedStockCountRow(StockItem item) {
                ReportDtos.StockCountVarianceRow row = new ReportDtos.StockCountVarianceRow();
                row.setProduct(item.getProduct() != null ? item.getProduct().getNameEn() : "-");
                row.setStore(item.getStore() != null ? item.getStore().getName() : "-");
                row.setDate(item.getUpdatedAt() == null ? LocalDate.now(REPORT_ZONE) : item.getUpdatedAt().atZone(REPORT_ZONE).toLocalDate());
                row.setSystemQty(safe(item.getQuantity()));
                row.setCountedQty(null);
                row.setVariance(null);
                row.setStatus("Not Counted");
                return row;
        }

        private ReportDtos.CashAdjustmentRow toCashAdjustmentRow(Shift shift) {
                ReportDtos.CashAdjustmentRow row = new ReportDtos.CashAdjustmentRow();
                row.setDate(shift.getClosedAt().atZone(REPORT_ZONE).toLocalDate());
                row.setCashier(shift.getOpenedBy() != null ? shift.getOpenedBy().getFullName() : "-");
                row.setExpectedCash(shift.getExpectedCash());
                row.setActualCash(shift.getClosingCash());
                row.setDifference(shift.getVariance());
                row.setStatus(shift.getStatus());
                return row;
        }

        private boolean auditCategoryMatches(String category, AuditLog log) {
                String key = Optional.ofNullable(category).orElse("").toLowerCase();
                String searchable = String.join(" ",
                                Optional.ofNullable(log.getAction()).orElse(""),
                                Optional.ofNullable(log.getEntity()).orElse(""),
                                Optional.ofNullable(log.getEntityId()).orElse(""),
                                Optional.ofNullable(log.getBeforeJson()).orElse(""),
                                Optional.ofNullable(log.getAfterJson()).orElse(""))
                                .toLowerCase();
                return switch (key) {
                        case "price-change" -> containsAny(searchable, "price", "unitprice", "sellprice", "costprice");
                        case "permission-change" -> containsAny(searchable, "role", "permission", "user_role");
                        case "deleted-transactions" -> containsAny(searchable, "delete", "void", "removed");
                        case "financial-adjustment" -> containsAny(searchable, "journal", "finance", "accounting",
                                        "financial", "correction");
                        case "approval-history" -> containsAny(searchable, "approve", "approval", "reject",
                                        "approved");
                        case "api-integration" -> containsAny(searchable, "api", "integration", "webhook", "sync");
                        case "error-log" -> containsAny(searchable, "error", "failed", "exception");
                        case "data-change" -> log.getBeforeJson() != null || log.getAfterJson() != null;
                        default -> true;
                };
        }

        private String actorName(AuditLog log) {
                if (log.getActor() == null) {
                        return "System";
                }
                return Optional.ofNullable(log.getActor().getFullName())
                                .filter(name -> !name.isBlank())
                                .orElse(log.getActor().getEmail());
        }

        private String moduleLabel(AuditLog log) {
                String entity = Optional.ofNullable(log.getEntity()).orElse("");
                if (!entity.isBlank()) {
                        return humanize(entity);
                }
                String action = Optional.ofNullable(log.getAction()).orElse("");
                int index = action.indexOf('_');
                return humanize(index > 0 ? action.substring(0, index) : action);
        }

        private String referenceLabel(AuditLog log) {
                if (log.getEntityId() != null && !log.getEntityId().isBlank()) {
                        return log.getEntityId();
                }
                return Optional.ofNullable(log.getAction()).orElse("-");
        }

        private String humanize(String value) {
                String clean = Optional.ofNullable(value).orElse("-").replace('_', ' ').replace('-', ' ').trim();
                if (clean.isBlank()) {
                        return "-";
                }
                String[] parts = clean.toLowerCase().split("\\s+");
                return java.util.Arrays.stream(parts)
                                .map(part -> part.isBlank() ? part
                                                : part.substring(0, 1).toUpperCase() + part.substring(1))
                                .collect(Collectors.joining(" "));
        }

        private String deviceLabel(String userAgent) {
                String agent = Optional.ofNullable(userAgent).orElse("").toLowerCase();
                if (agent.contains("android")) return "Android";
                if (agent.contains("iphone") || agent.contains("ipad")) return "iOS";
                if (agent.contains("windows")) return "Windows PC";
                if (agent.contains("mac")) return "Mac";
                if (agent.contains("linux")) return "Linux";
                return userAgent == null || userAgent.isBlank() ? "-" : "Device";
        }

        private String browserLabel(String userAgent) {
                String agent = Optional.ofNullable(userAgent).orElse("").toLowerCase();
                if (agent.contains("edg/")) return "Edge";
                if (agent.contains("chrome/")) return "Chrome";
                if (agent.contains("firefox/")) return "Firefox";
                if (agent.contains("safari/")) return "Safari";
                return userAgent == null || userAgent.isBlank() ? "-" : "Browser";
        }

        private boolean containsAny(String value, String... needles) {
                String text = Optional.ofNullable(value).orElse("").toLowerCase();
                for (String needle : needles) {
                        if (text.contains(needle.toLowerCase())) {
                                return true;
                        }
                }
                return false;
        }

        private Instant reportStart(LocalDate from) {
                return from.atStartOfDay(REPORT_ZONE).toInstant();
        }

        private Instant reportEnd(LocalDate to) {
                return to.plusDays(1).atStartOfDay(REPORT_ZONE).toInstant();
        }

        public Map<String, Object> getShiftSummary(Long shiftId) {
                var shift = shiftRepository.findById(shiftId)
                                .orElseThrow(() -> new ApiException("Shift not found"));

                // Calculate cash sales for this shift
                var shiftSales = saleRepository.findByShiftIdAndStatus(shiftId, "PAID");
                var cashPayments = shiftSales.stream()
                                .flatMap(sale -> sale.getPayments().stream())
                                .filter(payment -> "CASH".equals(payment.getMethod()))
                                .map(Payment::getAmount)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);

                var totalSales = shiftSales.stream()
                                .map(Sale::getGrandTotal)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);

                Map<String, Object> summary = new java.util.HashMap<>();
                summary.put("shiftId", shift.getId());
                summary.put("status", shift.getStatus());
                summary.put("openedAt", shift.getOpenedAt());
                summary.put("closedAt", shift.getClosedAt());
                summary.put("openedBy", shift.getOpenedBy() != null ? shift.getOpenedBy().getFullName() : null);
                summary.put("openingCash", shift.getOpeningCash());
                summary.put("closingCash", shift.getClosingCash());
                summary.put("totalSales", totalSales);
                summary.put("cashPayments", cashPayments);
                summary.put("salesCount", shiftSales.size());

                // Calculate expected cash (opening + cash sales)
                var expectedCash = shift.getOpeningCash().add(cashPayments);
                summary.put("expectedCash", expectedCash);

                // Calculate variance if shift is closed
                if (shift.getClosingCash() != null) {
                        summary.put("variance", shift.getClosingCash().subtract(expectedCash));
                }

                return summary;
        }

        @Transactional(readOnly = true)
        public ReportDtos.SalesReportResponse salesReport(LocalDate fromDate, LocalDate toDate,
                        Long customerId, Long storeId, Long cashierId, String paymentMethod,
                        Integer fromHour, Integer toHour, int page, int size) {
                List<Sale> rangeSales = filterSalesByInvoiceDateRange(fromDate, toDate);

                // Apply optional filters
                List<Sale> sales = rangeSales.stream()
                                .filter(sale -> customerId == null
                                                || (sale.getCustomer() != null
                                                                && customerId.equals(sale.getCustomer().getId())))
                                .filter(sale -> storeId == null
                                                || (sale.getShift() != null && sale.getShift().getStore() != null
                                                                && storeId.equals(sale.getShift().getStore().getId())))
                                .filter(sale -> cashierId == null
                                                || (sale.getCreatedBy() != null
                                                                && cashierId.equals(sale.getCreatedBy().getId())))
                                .filter(sale -> paymentMethod == null || paymentMethod.isBlank()
                                                || "ALL".equalsIgnoreCase(paymentMethod)
                                                || (sale.getPayments() != null && sale.getPayments().stream()
                                                                .anyMatch(p -> paymentMethod
                                                                                .equalsIgnoreCase(p.getMethod()))))
                                .filter(sale -> matchesHourRange(sale, fromHour, toHour))
                                .toList();

                // Calculate summary from filtered list
                ReportDtos.SalesReportSummary summary = new ReportDtos.SalesReportSummary();
                summary.setFromDate(fromDate);
                summary.setToDate(toDate);
                summary.setTotalGrossSales(
                                sales.stream().map(this::salesReportGrossAmount).reduce(BigDecimal.ZERO, BigDecimal::add));
                summary.setTotalNetSales(
                                sales.stream().map(Sale::getGrandTotal).reduce(BigDecimal.ZERO, BigDecimal::add));
                summary.setTotalPaidAmount(
                                sales.stream().map(this::salesReportPaidAmount).reduce(BigDecimal.ZERO, BigDecimal::add));
                summary.setTotalBalance(
                                sales.stream().map(this::salesReportBalance).reduce(BigDecimal.ZERO, BigDecimal::add));
                summary.setTotalTax(sales.stream().map(Sale::getTaxAmount).reduce(BigDecimal.ZERO, BigDecimal::add));
                summary.setTotalDiscount(
                                sales.stream().map(Sale::getDiscountAmount).reduce(BigDecimal.ZERO, BigDecimal::add));
                summary.setTotalSalesCount(sales.size());
                summary.setTotalItemsSold(sales.stream().flatMap(s -> s.getLines().stream())
                                .mapToLong(line -> line.getQuantity().longValue()).sum());
                summary.setAverageSaleAmount(sales.isEmpty() ? BigDecimal.ZERO
                                : summary.getTotalNetSales().divide(BigDecimal.valueOf(sales.size()), 2,
                                                java.math.RoundingMode.HALF_UP));

                // Convert sales to details (sorted by date desc)
                List<ReportDtos.SalesDetail> salesDetails = sales.stream()
                                .sorted(Comparator.comparing(Sale::getCreatedAt).reversed())
                                .map(sale -> {
                                        ReportDtos.SalesDetail detail = new ReportDtos.SalesDetail();
                                        BigDecimal paidAmount = salesReportPaidAmount(sale);
                                        BigDecimal balance = salesReportBalance(sale);
                                        detail.setSaleId(sale.getId());
                                        detail.setSaleNumber(reportDocumentNumber(sale));
                                        detail.setSaleDate(
                                                        resolveSaleInvoiceDate(sale));
                                        detail.setCustomerId(
                                                        sale.getCustomer() != null ? sale.getCustomer().getId()
                                                                        : null);
                                        detail.setCustomerName(
                                                        sale.getCustomer() != null ? sale.getCustomer().getNameEn()
                                                                        : "Walk-in");
                                        detail.setCashierId(
                                                        sale.getCreatedBy() != null ? sale.getCreatedBy().getId()
                                                                        : null);
                                        detail.setCashierName(
                                                        sale.getCreatedBy() != null
                                                                        ? sale.getCreatedBy().getFullName()
                                                                        : "Unknown");
                                        detail.setGrossAmount(salesReportGrossAmount(sale));
                                        detail.setNetAmount(sale.getGrandTotal());
                                        detail.setPaidAmount(paidAmount);
                                        detail.setBalance(balance);
                                        detail.setTaxAmount(sale.getTaxAmount());
                                        detail.setDiscountAmount(sale.getDiscountAmount());
                                        detail.setPaymentMethod(
                                                        sale.getPayments() != null && !sale.getPayments().isEmpty()
                                                                        ? sale.getPayments().get(0).getMethod()
                                                                        : "N/A");
                                        detail.setStatus(sale.getStatus());
                                        detail.setCreditSale(isReceivableSale(sale));
                                        if (sale.getTable() != null) {
                                                detail.setTableId(sale.getTable().getId());
                                                detail.setTableNumber(sale.getTable().getTableNumber());
                                        }
                                        List<ReportDtos.SaleItemDetail> items = sale.getLines().stream().map(line -> {
                                                ReportDtos.SaleItemDetail item = new ReportDtos.SaleItemDetail();
                                                item.setProductId(line.getProduct().getId());
                                                item.setProductNameEn(line.getProduct().getNameEn());
                                                item.setProductNameKm(line.getProduct().getNameKm());
                                                item.setSku(line.getProduct().getSku());
                                                item.setQuantity(line.getQuantity());
                                                item.setUnitPrice(line.getUnitPrice());
                                                item.setTotalPrice(line.getLineTotal());
                                                BigDecimal unitCost = line.getProduct().getCost() == null ? BigDecimal.ZERO : line.getProduct().getCost();
                                                item.setUnitCost(unitCost);
                                                item.setTotalCost(unitCost.multiply(line.getQuantity()));
                                                item.setDiscount(line.getLineDiscount());
                                                item.setRefundedQuantity(line.getRefundedQuantity());
                                                return item;
                                        }).collect(Collectors.toList());
                                        detail.setItems(items);
                                        return detail;
                                }).collect(Collectors.toList());

                // Payment breakdown from filtered sales
                Map<String, List<Payment>> byMethod = sales.stream()
                                .flatMap(s -> s.getPayments() != null ? s.getPayments().stream()
                                                : java.util.stream.Stream.empty())
                                .collect(Collectors.groupingBy(Payment::getMethod));
                List<ReportDtos.PaymentBreakdown> paymentBreakdown = byMethod.entrySet().stream().map(entry -> {
                        ReportDtos.PaymentBreakdown pb = new ReportDtos.PaymentBreakdown();
                        pb.setMethod(entry.getKey());
                        pb.setTotal(entry.getValue().stream().map(Payment::getAmount).reduce(BigDecimal.ZERO,
                                        BigDecimal::add));
                        pb.setCount(entry.getValue().size());
                        return pb;
                }).collect(Collectors.toList());

                // Top products from filtered sales
                Map<Long, List<SaleLine>> byProduct = sales.stream()
                                .flatMap(s -> s.getLines() != null ? s.getLines().stream()
                                                : java.util.stream.Stream.empty())
                                .collect(Collectors.groupingBy(sl -> sl.getProduct().getId()));
                List<ReportDtos.TopProduct> topProducts = byProduct.entrySet().stream().map(entry -> {
                        var lineList = entry.getValue();
                        var product = lineList.get(0).getProduct();
                        BigDecimal qty = lineList.stream().map(SaleLine::getQuantity).reduce(BigDecimal.ZERO,
                                        BigDecimal::add);
                        BigDecimal total = lineList.stream().map(SaleLine::getLineTotal).reduce(BigDecimal.ZERO,
                                        BigDecimal::add);
                        ReportDtos.TopProduct tp = new ReportDtos.TopProduct();
                        tp.setProductId(product.getId());
                        tp.setNameEn(product.getNameEn());
                        tp.setNameKm(product.getNameKm());
                        tp.setQuantity(qty);
                        tp.setTotal(total);
                        return tp;
                }).sorted(Comparator.comparing(ReportDtos.TopProduct::getTotal).reversed()).limit(10)
                                .collect(Collectors.toList());

                // Filter options from the full unfiltered range (so dropdowns stay populated)
                List<ReportDtos.SalesSummaryFilterOption> customerOptions = rangeSales.stream()
                                .filter(s -> s.getCustomer() != null)
                                .map(Sale::getCustomer)
                                .collect(Collectors.toMap(
                                                c -> String.valueOf(c.getId()),
                                                c -> c,
                                                (a, b) -> a,
                                                LinkedHashMap::new))
                                .values().stream()
                                .map(c -> {
                                        ReportDtos.SalesSummaryFilterOption opt = new ReportDtos.SalesSummaryFilterOption();
                                        opt.setValue(String.valueOf(c.getId()));
                                        opt.setLabel(c.getNameEn() != null ? c.getNameEn() : c.getNameKm());
                                        return opt;
                                }).toList();

                List<ReportDtos.SalesSummaryFilterOption> storeOptions = rangeSales.stream()
                                .filter(s -> s.getShift() != null && s.getShift().getStore() != null)
                                .map(s -> s.getShift().getStore())
                                .collect(Collectors.toMap(
                                                store -> String.valueOf(store.getId()),
                                                store -> store,
                                                (a, b) -> a,
                                                LinkedHashMap::new))
                                .values().stream()
                                .map(store -> {
                                        ReportDtos.SalesSummaryFilterOption opt = new ReportDtos.SalesSummaryFilterOption();
                                        opt.setValue(String.valueOf(store.getId()));
                                        opt.setLabel(store.getName());
                                        return opt;
                                }).toList();

                List<ReportDtos.SalesSummaryFilterOption> cashierOptions = rangeSales.stream()
                                .filter(s -> s.getCreatedBy() != null)
                                .map(Sale::getCreatedBy)
                                .collect(Collectors.toMap(
                                                u -> String.valueOf(u.getId()),
                                                u -> u,
                                                (a, b) -> a,
                                                LinkedHashMap::new))
                                .values().stream()
                                .map(u -> {
                                        ReportDtos.SalesSummaryFilterOption opt = new ReportDtos.SalesSummaryFilterOption();
                                        opt.setValue(String.valueOf(u.getId()));
                                        opt.setLabel(u.getFullName());
                                        return opt;
                                }).toList();

                List<ReportDtos.SalesSummaryFilterOption> pmOptions = rangeSales.stream()
                                .flatMap(s -> s.getPayments() != null ? s.getPayments().stream()
                                                : java.util.stream.Stream.empty())
                                .map(Payment::getMethod)
                                .filter(m -> m != null && !m.isBlank())
                                .distinct().sorted()
                                .map(m -> {
                                        ReportDtos.SalesSummaryFilterOption opt = new ReportDtos.SalesSummaryFilterOption();
                                        opt.setValue(m);
                                        opt.setLabel(m.replace('_', ' '));
                                        return opt;
                                }).toList();

                ReportDtos.SalesReportResponse response = new ReportDtos.SalesReportResponse();
                response.setSummary(summary);
                response.setSales(paginate(salesDetails, page, size));
                response.setPaymentBreakdown(paymentBreakdown);
                response.setTopProducts(topProducts);
                response.setCustomers(customerOptions);
                response.setStores(storeOptions);
                response.setCashiers(cashierOptions);
                response.setPaymentOptions(pmOptions);

                return response;
        }

        private BigDecimal salesReportPaidAmount(Sale sale) {
                if (sale.getPaidAmount() != null) {
                        return sale.getPaidAmount().max(BigDecimal.ZERO);
                }
                if (sale.getPayments() == null) {
                        return BigDecimal.ZERO;
                }
                return sale.getPayments().stream()
                                .map(Payment::getAmount)
                                .filter(java.util.Objects::nonNull)
                                .reduce(BigDecimal.ZERO, BigDecimal::add)
                                .max(BigDecimal.ZERO);
        }

        private BigDecimal salesReportBalance(Sale sale) {
                BigDecimal total = sale.getGrandTotal() != null ? sale.getGrandTotal() : BigDecimal.ZERO;
                return total.subtract(salesReportPaidAmount(sale)).max(BigDecimal.ZERO);
        }

        private boolean isReceivableSale(Sale sale) {
                return sale.getCreditIssuedAt() != null
                                || "CREDIT".equalsIgnoreCase(sale.getStatus())
                                || salesReportBalance(sale).compareTo(BigDecimal.ZERO) > 0;
        }

        private BigDecimal salesReportGrossAmount(Sale sale) {
                BigDecimal grandTotal = safe(sale.getGrandTotal());
                BigDecimal discount = safe(sale.getDiscountAmount());
                BigDecimal tax = safe(sale.getTaxAmount());
                BigDecimal calculatedGross = grandTotal.add(discount).subtract(tax);
                if (calculatedGross.compareTo(BigDecimal.ZERO) > 0) {
                        return calculatedGross;
                }
                return safe(sale.getSubtotal());
        }

        private ReportDtos.ProfitLossInvoiceRow toProfitLossInvoiceRow(Sale sale) {
                ReportDtos.ProfitLossInvoiceRow row = new ReportDtos.ProfitLossInvoiceRow();
                row.setSaleId(sale.getId());
                row.setInvoiceNumber(reportDocumentNumber(sale));
                row.setInvoiceDate(resolveSaleInvoiceDate(sale));
                row.setCustomerName(sale.getCustomer() == null
                                ? "Walk-in"
                                : firstNonBlank(
                                                firstNonBlank(sale.getCustomer().getDisplayName(), sale.getCustomer().getNameEn()),
                                                sale.getCustomer().getNameKm()));
                row.setStatus(sale.getStatus());
                row.setPaymentMethod(sale.getPayments() == null || sale.getPayments().isEmpty()
                                ? "-"
                                : sale.getPayments().stream()
                                                .map(Payment::getMethod)
                                                .filter(method -> method != null && !method.isBlank())
                                                .distinct()
                                                .sorted()
                                                .collect(Collectors.joining(", ")));
                row.setGrossAmount(safe(sale.getSubtotal()));
                row.setDiscountAmount(safe(sale.getDiscountAmount()));
                row.setTaxAmount(safe(sale.getTaxAmount()));
                row.setNetAmount(safe(sale.getGrandTotal()));
                row.setPaidAmount(salesReportPaidAmount(sale));
                row.setBalance(salesReportBalance(sale));
                return row;
        }

        private ReportDtos.ProfitLossExpenseRow toProfitLossExpenseRow(Expense expense) {
                ReportDtos.ProfitLossExpenseRow row = new ReportDtos.ProfitLossExpenseRow();
                row.setExpenseId(expense.getId());
                row.setExpenseDate(expense.getExpenseDate());
                row.setExpenseNumber(expense.getExpenseNumber());
                row.setCategoryNameEn(expense.getCategory() != null ? expense.getCategory().getNameEn() : null);
                row.setCategoryNameKm(expense.getCategory() != null ? expense.getCategory().getNameKm() : null);
                row.setDescription(expense.getDescription());
                row.setPaymentMethod(expense.getPaymentMethod());
                row.setReference(expense.getReference());
                row.setAmount(safe(expense.getAmount()));
                return row;
        }

        private ReportDtos.ProfitLossExpenseRow toProfitLossPayrollExpenseRow(PayrollRun run) {
                ReportDtos.ProfitLossExpenseRow row = new ReportDtos.ProfitLossExpenseRow();
                row.setExpenseId(run.getId());
                row.setExpenseDate(run.getPayDate());
                row.setExpenseNumber("PAYROLL-" + run.getId());
                row.setCategoryNameEn("Employee Payroll Expense");
                row.setCategoryNameKm("ចំណាយបើកប្រាក់ខែបុគ្គលិក");
                row.setDescription("Payroll " + run.getPeriodStart() + " - " + run.getPeriodEnd());
                row.setPaymentMethod("PAYROLL");
                row.setReference("Payroll #" + run.getId());
                row.setAmount(safe(run.getTotalGross()));
                return row;
        }

        private ReportDtos.ProfitLossOtherIncomeRow toProfitLossOtherIncomeRow(OtherIncome income) {
                ReportDtos.ProfitLossOtherIncomeRow row = new ReportDtos.ProfitLossOtherIncomeRow();
                row.setIncomeId(income.getId());
                row.setIncomeDate(income.getIncomeDate());
                row.setIncomeNumber(income.getIncomeNumber());
                row.setCategoryNameEn(income.getCategory() != null ? income.getCategory().getNameEn() : null);
                row.setCategoryNameKm(income.getCategory() != null ? income.getCategory().getNameKm() : null);
                row.setPayerName(income.getPayerName());
                row.setDescription(income.getDescription());
                row.setPaymentMethod(income.getPaymentMethod());
                row.setReference(income.getReference());
                row.setAmount(safe(income.getAmount()));
                return row;
        }

        // EOD Owner Report Methods
        @Transactional
        public ReportDtos.EodRunResponse runEodReport(LocalDate eodDate, String processedBy) {
                // Check if EOD already exists for this date
                Optional<EodSnapshot> existing = eodSnapshotRepository.findByEodDate(eodDate);
                if (existing.isPresent() && "COMPLETED".equals(existing.get().getStatus())) {
                        throw new ApiException("EOD report already exists for date: " + eodDate);
                }

                EodSnapshot snapshot = existing.orElse(new EodSnapshot());
                snapshot.setEodDate(eodDate);
                snapshot.setStatus("PROCESSING");
                snapshot.setProcessedBy(processedBy);
                snapshot = eodSnapshotRepository.save(snapshot);

                try {
                        // Calculate EOD data
                        calculateEodSummary(snapshot);
                        calculateInvoiceSnapshots(snapshot);
                        calculateCollectionSummary(snapshot);
                        calculateAgingSummary(snapshot);
                        calculateCustomerCredits(snapshot);

                        snapshot.setStatus("COMPLETED");
                        eodSnapshotRepository.save(snapshot);

                        return createEodRunResponse(snapshot.getId(), "COMPLETED", "EOD report generated successfully");

                } catch (Exception e) {
                        snapshot.setStatus("FAILED");
                        eodSnapshotRepository.save(snapshot);
                        throw new ApiException("Failed to generate EOD report: " + e.getMessage());
                }
        }

        public ReportDtos.EodReportResponse getEodReport(LocalDate date) {
                Optional<EodSnapshot> snapshot = eodSnapshotRepository.findCompletedByDate(date);
                if (snapshot.isPresent()) {
                        return buildEodReportFromSnapshot(snapshot.get());
                }
                return buildLiveEodReport(date);
        }

        private ReportDtos.EodReportResponse buildEodReportFromSnapshot(EodSnapshot snapshot) {
                ReportDtos.EodReportResponse response = new ReportDtos.EodReportResponse();

                ReportDtos.EodSummary summary = new ReportDtos.EodSummary();
                summary.setEodDate(snapshot.getEodDate());
                summary.setStatus(snapshot.getStatus());
                summary.setSource("SNAPSHOT");
                summary.setSnapshotBacked(true);
                summary.setNetSalesToday(snapshot.getNetSalesToday());
                summary.setCashCollectedToday(snapshot.getCashCollectedToday());
                summary.setNewCreditToday(snapshot.getNewCreditToday());
                summary.setTotalArBalance(snapshot.getTotalArBalance());
                summary.setOverdueGt30Days(snapshot.getOverdueGt30Days());
                summary.setTotalSalesCount(snapshot.getTotalSalesCount());
                summary.setTotalPaymentsCount(snapshot.getTotalPaymentsCount());
                summary.setProcessedAt(snapshot.getProcessedAt());
                response.setSummary(summary);

                List<ReportDtos.EodInvoiceRow> invoiceRows = snapshot.getInvoiceSnapshots().stream()
                                .map(this::mapToEodInvoiceRow)
                                .sorted((a, b) -> Integer.compare(b.getDaysOutstanding(), a.getDaysOutstanding()))
                                .collect(Collectors.toList());
                response.setInvoices(invoiceRows);

                List<ReportDtos.EodCollectionSummary> collectionSummary = snapshot.getCollectionSummaries().stream()
                                .map(this::mapToEodCollectionSummary)
                                .collect(Collectors.toList());
                response.setCollectionSummary(collectionSummary);

                List<ReportDtos.EodAgingSummary> agingSummary = snapshot.getAgingSummaries().stream()
                                .map(this::mapToEodAgingSummary)
                                .collect(Collectors.toList());
                response.setAgingSummary(agingSummary);

                List<ReportDtos.EodCustomerCredit> customerCredits = snapshot.getCustomerCredits().stream()
                                .map(this::mapToEodCustomerCredit)
                                .collect(Collectors.toList());
                response.setCustomerCredits(customerCredits);

                return response;
        }

        private ReportDtos.EodReportResponse buildLiveEodReport(LocalDate date) {
                var start = date.atStartOfDay().toInstant(ZoneOffset.UTC);
                var end = date.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);

                List<Sale> todaySales = filterSalesByRange(start, end);
                List<Sale> outstandingSales = saleRepository.findOutstandingReportSales();

                ReportDtos.EodSummary summary = new ReportDtos.EodSummary();
                summary.setEodDate(date);
                summary.setStatus("LIVE");
                summary.setSource("LIVE");
                summary.setSnapshotBacked(false);
                summary.setNetSalesToday(todaySales.stream()
                                .map(Sale::getGrandTotal)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                summary.setCashCollectedToday(todaySales.stream()
                                .flatMap(sale -> sale.getPayments().stream())
                                .filter(payment -> payment.getCreatedAt() != null)
                                .filter(payment -> payment.getCreatedAt().atZone(ZoneId.of("UTC")).toLocalDate()
                                                .equals(date))
                                .filter(payment -> "CASH".equals(payment.getMethod()) ||
                                                "CARD".equals(payment.getMethod()) ||
                                                "QR".equals(payment.getMethod()))
                                .map(Payment::getAmount)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                summary.setNewCreditToday(todaySales.stream()
                                .filter(sale -> "CREDIT".equals(sale.getStatus()))
                                .map(Sale::getGrandTotal)
                                .reduce(BigDecimal.ZERO, BigDecimal::add));
                summary.setTotalArBalance(saleRepository.sumOpenReceivableOutstanding());
                summary.setOverdueGt30Days(saleRepository.sumOpenReceivableOutstandingBefore(
                                date.minusDays(30).atStartOfDay().toInstant(ZoneOffset.UTC)));
                summary.setTotalSalesCount(todaySales.size());
                summary.setTotalPaymentsCount((int) todaySales.stream()
                                .flatMap(sale -> sale.getPayments().stream())
                                .filter(payment -> payment.getCreatedAt() != null)
                                .filter(payment -> payment.getCreatedAt().atZone(ZoneId.of("UTC")).toLocalDate()
                                                .equals(date))
                                .count());

                List<ReportDtos.EodInvoiceRow> invoiceRows = outstandingSales.stream()
                                .map(sale -> mapSaleToLiveInvoiceRow(sale, date))
                                .sorted((a, b) -> Integer.compare(b.getDaysOutstanding(), a.getDaysOutstanding()))
                                .collect(Collectors.toList());

                Map<String, List<Payment>> paymentsByMethod = todaySales.stream()
                                .flatMap(sale -> sale.getPayments().stream())
                                .filter(payment -> payment.getCreatedAt() != null)
                                .filter(payment -> payment.getCreatedAt().atZone(ZoneId.of("UTC")).toLocalDate()
                                                .equals(date))
                                .collect(Collectors.groupingBy(Payment::getMethod));
                List<ReportDtos.EodCollectionSummary> collectionSummary = paymentsByMethod.entrySet().stream()
                                .map(entry -> {
                                        ReportDtos.EodCollectionSummary dto = new ReportDtos.EodCollectionSummary();
                                        dto.setPaymentMethod(entry.getKey());
                                        dto.setTotalAmount(entry.getValue().stream()
                                                        .map(Payment::getAmount)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        dto.setTransactionCount(entry.getValue().size());
                                        return dto;
                                })
                                .collect(Collectors.toList());

                Map<String, List<ReportDtos.EodInvoiceRow>> invoicesByAging = invoiceRows.stream()
                                .filter(row -> row.getBalance().compareTo(BigDecimal.ZERO) > 0)
                                .collect(Collectors.groupingBy(ReportDtos.EodInvoiceRow::getAgingBucket));
                List<ReportDtos.EodAgingSummary> agingSummary = invoicesByAging.entrySet().stream()
                                .map(entry -> {
                                        ReportDtos.EodAgingSummary dto = new ReportDtos.EodAgingSummary();
                                        dto.setAgingBucket(entry.getKey());
                                        dto.setTotalBalance(entry.getValue().stream()
                                                        .map(ReportDtos.EodInvoiceRow::getBalance)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add));
                                        dto.setInvoiceCount(entry.getValue().size());
                                        return dto;
                                })
                                .collect(Collectors.toList());

                List<ReportDtos.EodCustomerCredit> customerCredits = outstandingSales.stream()
                                .filter(sale -> sale.getCustomer() != null)
                                .collect(Collectors.groupingBy(sale -> sale.getCustomer().getId()))
                                .values().stream()
                                .map(customerSales -> {
                                        Customer customer = customerSales.get(0).getCustomer();
                                        BigDecimal currentBalance = customerSales.stream()
                                                        .map(this::calculateBalance)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add);

                                        ReportDtos.EodCustomerCredit dto = new ReportDtos.EodCustomerCredit();
                                        dto.setCustomerId(customer.getId());
                                        dto.setCustomerName(customer.getNameEn());
                                        dto.setCreditLimit(customer.getCreditLimit());
                                        dto.setCurrentBalance(currentBalance);
                                        dto.setStatus(calculateCreditStatus(customer.getCreditLimit(),
                                                        currentBalance));
                                        return dto;
                                })
                                .collect(Collectors.toList());

                ReportDtos.EodReportResponse response = new ReportDtos.EodReportResponse();
                response.setSummary(summary);
                response.setInvoices(invoiceRows);
                response.setCollectionSummary(collectionSummary);
                response.setAgingSummary(agingSummary);
                response.setCustomerCredits(customerCredits);
                return response;
        }

        private void calculateEodSummary(EodSnapshot snapshot) {
                LocalDate eodDate = snapshot.getEodDate();
                var start = eodDate.atStartOfDay().toInstant(ZoneOffset.UTC);
                var end = eodDate.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);

                List<Sale> todaySales = filterSalesByRange(start, end);

                BigDecimal netSalesToday = todaySales.stream()
                                .map(Sale::getGrandTotal)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);

                BigDecimal cashCollectedToday = todaySales.stream()
                                .flatMap(sale -> sale.getPayments().stream())
                                .filter(payment -> payment.getCreatedAt().toLocalDate().equals(eodDate))
                                .filter(payment -> "CASH".equals(payment.getMethod()) ||
                                                "CARD".equals(payment.getMethod()) ||
                                                "QR".equals(payment.getMethod()))
                                .map(Payment::getAmount)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);

                BigDecimal newCreditToday = todaySales.stream()
                                .filter(sale -> "CREDIT".equals(sale.getStatus()))
                                .map(Sale::getGrandTotal)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);

                BigDecimal totalArBalance = saleRepository.sumOpenReceivableOutstanding();
                BigDecimal overdueGt30Days = saleRepository.sumOpenReceivableOutstandingBefore(
                                eodDate.minusDays(30).atStartOfDay().toInstant(ZoneOffset.UTC));

                snapshot.setNetSalesToday(netSalesToday);
                snapshot.setCashCollectedToday(cashCollectedToday);
                snapshot.setNewCreditToday(newCreditToday);
                snapshot.setTotalArBalance(totalArBalance);
                snapshot.setOverdueGt30Days(overdueGt30Days);
                snapshot.setTotalSalesCount(todaySales.size());
                snapshot.setTotalPaymentsCount((int) todaySales.stream()
                                .mapToLong(sale -> sale.getPayments().size()).sum());
        }

        private void calculateInvoiceSnapshots(EodSnapshot snapshot) {
                List<Sale> allSales = saleRepository.findOutstandingReportSales();
                List<EodInvoiceSnapshot> invoiceSnapshots = new ArrayList<>();

                for (Sale sale : allSales) {
                        EodInvoiceSnapshot invoiceSnapshot = new EodInvoiceSnapshot();
                        invoiceSnapshot.setEodSnapshot(snapshot);
                        invoiceSnapshot.setSale(sale);
                        invoiceSnapshot.setInvoiceNo(reportDocumentNumber(sale));
                        invoiceSnapshot.setInvoiceDate(sale.getCreatedAt().atZone(ZoneId.of("UTC")).toLocalDate());
                        invoiceSnapshot.setCustomer(sale.getCustomer());
                        invoiceSnapshot.setCustomerName(
                                        sale.getCustomer() != null ? sale.getCustomer().getNameEn() : "Walk-in");
                        invoiceSnapshot.setTotalSale(sale.getGrandTotal());

                        BigDecimal paidAmount = sale.getPayments().stream()
                                        .map(Payment::getAmount)
                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                        invoiceSnapshot.setPaidAmount(paidAmount);

                        BigDecimal balance = sale.getGrandTotal().subtract(paidAmount);
                        invoiceSnapshot.setBalance(balance);

                        int daysOutstanding = balance.compareTo(BigDecimal.ZERO) > 0
                                        ? (int) java.time.temporal.ChronoUnit.DAYS.between(
                                                        sale.getCreatedAt().atZone(ZoneId.of("UTC")).toLocalDate(),
                                                        snapshot.getEodDate())
                                        : 0;
                        invoiceSnapshot.setDaysOutstanding(daysOutstanding);

                        String agingBucket = calculateAgingBucket(daysOutstanding);
                        invoiceSnapshot.setAgingBucket(agingBucket);

                        String paymentStatus = calculatePaymentStatus(sale, balance);
                        invoiceSnapshot.setPaymentStatus(paymentStatus);

                        invoiceSnapshots.add(invoiceSnapshot);
                }

                snapshot.setInvoiceSnapshots(invoiceSnapshots);
        }

        private void calculateCollectionSummary(EodSnapshot snapshot) {
                LocalDate eodDate = snapshot.getEodDate();
                var start = eodDate.atStartOfDay().toInstant(ZoneOffset.UTC);
                var end = eodDate.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);

                Map<String, List<Payment>> paymentsByMethod = filterSalesByRange(start, end).stream()
                                .flatMap(sale -> sale.getPayments().stream())
                                .collect(Collectors.groupingBy(Payment::getMethod));

                List<EodCollectionSummary> collectionSummaries = paymentsByMethod.entrySet().stream()
                                .map(entry -> {
                                        EodCollectionSummary summary = new EodCollectionSummary();
                                        summary.setEodSnapshot(snapshot);
                                        summary.setPaymentMethod(entry.getKey());
                                        BigDecimal total = entry.getValue().stream()
                                                        .map(Payment::getAmount)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                                        summary.setTotalAmount(total);
                                        summary.setTransactionCount(entry.getValue().size());
                                        return summary;
                                })
                                .collect(Collectors.toList());

                snapshot.setCollectionSummaries(collectionSummaries);
        }

        private void calculateAgingSummary(EodSnapshot snapshot) {
                Map<String, List<EodInvoiceSnapshot>> invoicesByAging = snapshot.getInvoiceSnapshots().stream()
                                .filter(invoice -> invoice.getBalance().compareTo(BigDecimal.ZERO) > 0)
                                .collect(Collectors.groupingBy(EodInvoiceSnapshot::getAgingBucket));

                List<EodAgingSummary> agingSummaries = invoicesByAging.entrySet().stream()
                                .map(entry -> {
                                        EodAgingSummary summary = new EodAgingSummary();
                                        summary.setEodSnapshot(snapshot);
                                        summary.setAgingBucket(entry.getKey());
                                        BigDecimal totalBalance = entry.getValue().stream()
                                                        .map(EodInvoiceSnapshot::getBalance)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                                        summary.setTotalBalance(totalBalance);
                                        summary.setInvoiceCount(entry.getValue().size());
                                        return summary;
                                })
                                .collect(Collectors.toList());

                snapshot.setAgingSummaries(agingSummaries);
        }

        private void calculateCustomerCredits(EodSnapshot snapshot) {
                // Get all customers with credit
                List<EodCustomerCredit> customerCredits = snapshot.getInvoiceSnapshots().stream()
                                .filter(invoice -> invoice.getCustomer() != null)
                                .collect(Collectors.groupingBy(invoice -> invoice.getCustomer().getId()))
                                .entrySet().stream()
                                .map(entry -> {
                                        Customer customer = entry.getValue().get(0).getCustomer();
                                        BigDecimal currentBalance = entry.getValue().stream()
                                                        .map(EodInvoiceSnapshot::getBalance)
                                                        .reduce(BigDecimal.ZERO, BigDecimal::add);

                                        EodCustomerCredit credit = new EodCustomerCredit();
                                        credit.setEodSnapshot(snapshot);
                                        credit.setCustomer(customer);
                                        credit.setCustomerName(customer.getNameEn());
                                        credit.setCreditLimit(customer.getCreditLimit());
                                        credit.setCurrentBalance(currentBalance);
                                        credit.setStatus(calculateCreditStatus(customer.getCreditLimit(),
                                                        currentBalance));
                                        return credit;
                                })
                                .collect(Collectors.toList());

                snapshot.setCustomerCredits(customerCredits);
        }

        private BigDecimal calculateBalance(Sale sale) {
                BigDecimal total = sale.getGrandTotal();
                BigDecimal paid = sale.getPayments().stream()
                                .map(Payment::getAmount)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);
                return total.subtract(paid);
        }

        private ReportDtos.EodInvoiceRow mapSaleToLiveInvoiceRow(Sale sale, LocalDate eodDate) {
                BigDecimal paidAmount = sale.getPayments().stream()
                                .map(Payment::getAmount)
                                .reduce(BigDecimal.ZERO, BigDecimal::add);
                BigDecimal balance = sale.getGrandTotal().subtract(paidAmount);
                int daysOutstanding = balance.compareTo(BigDecimal.ZERO) > 0
                                ? (int) java.time.temporal.ChronoUnit.DAYS.between(
                                                sale.getCreatedAt().atZone(ZoneId.of("UTC")).toLocalDate(),
                                                eodDate)
                                : 0;

                ReportDtos.EodInvoiceRow row = new ReportDtos.EodInvoiceRow();
                row.setSaleId(sale.getId());
                row.setInvoiceNo(reportDocumentNumber(sale));
                row.setInvoiceDate(sale.getCreatedAt().atZone(ZoneId.of("UTC")).toLocalDate());
                row.setCustomerName(sale.getCustomer() != null ? sale.getCustomer().getNameEn() : "Walk-in");
                row.setTotalSale(sale.getGrandTotal());
                row.setPaidAmount(paidAmount);
                row.setBalance(balance);
                row.setDaysOutstanding(daysOutstanding);
                row.setAgingBucket(calculateAgingBucket(daysOutstanding));
                row.setPaymentStatus(calculatePaymentStatus(sale, balance));
                return row;
        }

        private String calculateAgingBucket(int daysOutstanding) {
                if (daysOutstanding == 0)
                        return "0-7";
                if (daysOutstanding <= 7)
                        return "0-7";
                if (daysOutstanding <= 15)
                        return "8-15";
                if (daysOutstanding <= 30)
                        return "16-30";
                return ">30";
        }

        private String calculatePaymentStatus(Sale sale, BigDecimal balance) {
                if (balance.compareTo(BigDecimal.ZERO) == 0)
                        return "PAID";
                if (balance.compareTo(sale.getGrandTotal()) < 0)
                        return "PARTIAL";
                return "CREDIT";
        }

        private String calculateCreditStatus(BigDecimal creditLimit, BigDecimal currentBalance) {
                if (currentBalance.compareTo(creditLimit) > 0)
                        return "OVER_LIMIT";
                if (currentBalance.compareTo(creditLimit.multiply(BigDecimal.valueOf(0.8))) > 0)
                        return "WARNING";
                return "OK";
        }

        private ReportDtos.EodInvoiceRow mapToEodInvoiceRow(EodInvoiceSnapshot snapshot) {
                ReportDtos.EodInvoiceRow row = new ReportDtos.EodInvoiceRow();
                row.setSaleId(snapshot.getSale().getId());
                row.setInvoiceNo(snapshot.getInvoiceNo());
                row.setInvoiceDate(snapshot.getInvoiceDate());
                row.setCustomerName(snapshot.getCustomerName());
                row.setTotalSale(snapshot.getTotalSale());
                row.setPaidAmount(snapshot.getPaidAmount());
                row.setBalance(snapshot.getBalance());
                row.setDaysOutstanding(snapshot.getDaysOutstanding());
                row.setAgingBucket(snapshot.getAgingBucket());
                row.setPaymentStatus(snapshot.getPaymentStatus());
                return row;
        }

        private ReportDtos.EodCollectionSummary mapToEodCollectionSummary(EodCollectionSummary summary) {
                ReportDtos.EodCollectionSummary dto = new ReportDtos.EodCollectionSummary();
                dto.setPaymentMethod(summary.getPaymentMethod());
                dto.setTotalAmount(summary.getTotalAmount());
                dto.setTransactionCount(summary.getTransactionCount());
                return dto;
        }

        private ReportDtos.EodAgingSummary mapToEodAgingSummary(EodAgingSummary summary) {
                ReportDtos.EodAgingSummary dto = new ReportDtos.EodAgingSummary();
                dto.setAgingBucket(summary.getAgingBucket());
                dto.setTotalBalance(summary.getTotalBalance());
                dto.setInvoiceCount(summary.getInvoiceCount());
                return dto;
        }

        private ReportDtos.EodCustomerCredit mapToEodCustomerCredit(EodCustomerCredit credit) {
                ReportDtos.EodCustomerCredit dto = new ReportDtos.EodCustomerCredit();
                dto.setCustomerId(credit.getCustomer().getId());
                dto.setCustomerName(credit.getCustomerName());
                dto.setCreditLimit(credit.getCreditLimit());
                dto.setCurrentBalance(credit.getCurrentBalance());
                dto.setStatus(credit.getStatus());
                return dto;
        }

        private ReportDtos.EodRunResponse createEodRunResponse(Long snapshotId, String status, String message) {
                ReportDtos.EodRunResponse response = new ReportDtos.EodRunResponse();
                response.setSnapshotId(snapshotId);
                response.setStatus(status);
                response.setMessage(message);
                return response;
        }
}
