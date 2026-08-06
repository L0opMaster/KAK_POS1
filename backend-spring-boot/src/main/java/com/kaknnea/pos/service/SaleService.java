package com.kaknnea.pos.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.text.Normalizer;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.dto.SaleDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.*;
import com.kaknnea.pos.domain.CustomerCreditAllocation;
import com.kaknnea.pos.util.DocumentNumberUtil;
import com.kaknnea.pos.util.SecurityUtil;
// import com.kaknnea.pos.service.AuditService;
// import com.kaknnea.pos.service.PdfService;

@Service
public class SaleService {
    private static final Logger log = LoggerFactory.getLogger(SaleService.class);
    private static final BigDecimal REFUND_APPROVAL_THRESHOLD = new BigDecimal("50.00");
    private static final ObjectMapper MODIFIER_MAPPER = new ObjectMapper();

    private final SaleRepository saleRepository;
    private final ProductRepository productRepository;
    private final StockItemRepository stockItemRepository;
    private final StockMovementRepository stockMovementRepository;
    private final PaymentRepository paymentRepository;
    private final SaleDiscountRepository saleDiscountRepository;
    private final CustomerRepository customerRepository;
    private final CustomerCreditAccountRepository creditAccountRepository;
    private final ShiftRepository shiftRepository;
    private final BusinessSettingsRepository businessSettingsRepository;
    private final TableRepository tableRepository;
    private final PdfService pdfService;
    private final AuditService auditService;
    private final CashEventService cashEventService;
    private final UserRepository userRepository;
    private final StoreRepository storeRepository;
    private final PasswordEncoder passwordEncoder;
    private final PriceListService priceListService;
    private final CreditCollectionService creditCollectionService;
    private final CustomerCreditAllocationRepository creditAllocationRepository;
    private final EmailService emailService;
    private final CurrencySettingRepository currencySettingRepository;

    public SaleService(SaleRepository saleRepository,
            ProductRepository productRepository,
            StockItemRepository stockItemRepository,
            StockMovementRepository stockMovementRepository,
            PaymentRepository paymentRepository,
            SaleDiscountRepository saleDiscountRepository,
            CustomerRepository customerRepository,
            CustomerCreditAccountRepository creditAccountRepository,
            ShiftRepository shiftRepository,
            BusinessSettingsRepository businessSettingsRepository,
            TableRepository tableRepository,
            PdfService pdfService,
            AuditService auditService,
            CashEventService cashEventService,
            UserRepository userRepository,
            StoreRepository storeRepository,
            PasswordEncoder passwordEncoder,
            PriceListService priceListService,
            CreditCollectionService creditCollectionService,
            CustomerCreditAllocationRepository creditAllocationRepository,
            EmailService emailService,
            CurrencySettingRepository currencySettingRepository) {
        this.saleRepository = saleRepository;
        this.productRepository = productRepository;
        this.stockItemRepository = stockItemRepository;
        this.stockMovementRepository = stockMovementRepository;
        this.paymentRepository = paymentRepository;
        this.saleDiscountRepository = saleDiscountRepository;
        this.customerRepository = customerRepository;
        this.creditAccountRepository = creditAccountRepository;
        this.shiftRepository = shiftRepository;
        this.businessSettingsRepository = businessSettingsRepository;
        this.tableRepository = tableRepository;
        this.pdfService = pdfService;
        this.auditService = auditService;
        this.cashEventService = cashEventService;
        this.userRepository = userRepository;
        this.storeRepository = storeRepository;
        this.passwordEncoder = passwordEncoder;
        this.priceListService = priceListService;
        this.creditCollectionService = creditCollectionService;
        this.creditAllocationRepository = creditAllocationRepository;
        this.emailService = emailService;
        this.currencySettingRepository = currencySettingRepository;
    }

    /** The KHR-per-USD rate currently configured in Settings, or null if KHR isn't set up. */
    private BigDecimal currentKhrExchangeRate() {
        return currencySettingRepository.findByCode("KHR")
                .map(CurrencySetting::getExchangeRate)
                .orElse(null);
    }

    // All methods (create, update, hold, resume, voidSale, pay, credit, refund,
    // repayCreditSale, receipt, invoicePdf, listByStatus, listByShift) are already
    // implemented below and inside this class.
    // ...existing methods...

    @Transactional
    public SaleDtos.SaleResponse create(SaleDtos.SaleCreateRequest request) {
        if (request.getClientRef() != null && !request.getClientRef().isBlank()) {
            Sale existing = saleRepository.findByClientRef(request.getClientRef()).orElse(null);
            if (existing != null) {
                return toResponse(existing);
            }
        }

        Sale sale = new Sale();
        sale.setStatus("DRAFT");
        sale.setClientRef(request.getClientRef());
        sale.setDisplayName(trimToNull(request.getDisplayName()));

        // Set current shift
        User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow();
        sale.setCreatedBy(actor);
        Shift currentShift = shiftRepository.findFirstByOpenedByIdAndStatusOrderByOpenedAtDesc(actor.getId(), "OPEN")
                .orElse(null);
        sale.setShift(currentShift);
        sale.setTerminalId(request.getTerminalId());

        if (request.getCustomerId() != null) {
            sale.setCustomer(customerRepository.findById(request.getCustomerId()).orElse(null));
        }

        sale.setOrderDate(parseDateOrDefault(request.getOrderDate(), LocalDate.now()));
        sale.setDeliveryDate(parseDate(request.getDeliveryDate()));
        sale.setPaymentTerms(resolvePaymentTerms(request.getPaymentTerms(), sale.getCustomer()));
        sale.setDeliveryCharge(safeAmount(request.getDeliveryCharge()));
        sale.setOtherCharge(safeAmount(request.getOtherCharge()));
        sale.setDepositAmount(safeAmount(request.getDepositAmount()));

        if (request.getTableId() != null) {
            sale.setTable(tableRepository.findById(request.getTableId()).orElse(null));
        }

        List<SaleLine> lines = request.getLines().stream().map(lineReq -> {
            Product product = productRepository.findById(lineReq.getProductId())
                .orElseThrow(() -> new ApiException("Product not found"));
            BigDecimal unitPrice = resolveUnitPrice(lineReq, product, sale.getCustomer())
                .add(modifierPriceDelta(lineReq.getModifierData()));
            SaleLine line = new SaleLine();
            line.setSale(sale);
            line.setProduct(product);
            line.setQuantity(lineReq.getQuantity());
            line.setUnitPrice(unitPrice);
            line.setLineDiscount(lineReq.getLineDiscount() == null ? BigDecimal.ZERO : lineReq.getLineDiscount());
            line.setLineNote(lineReq.getNote());
            line.setModifierSummary(lineReq.getModifierSummary());
            line.setModifierData(lineReq.getModifierData());
            BigDecimal lineTotal = unitPrice.multiply(lineReq.getQuantity())
                .subtract(line.getLineDiscount());
            line.setLineTotal(lineTotal);
            return line;
        }).collect(Collectors.toList());
        sale.getLines().clear();
        sale.getLines().addAll(lines);
        validateSaleStockAvailable(sale);

        BigDecimal subtotal = lines.stream().map(SaleLine::getLineTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal discount = request.getInvoiceDiscount() == null ? BigDecimal.ZERO : request.getInvoiceDiscount();
        BigDecimal taxable = subtotal.subtract(discount);
        BigDecimal taxAmount = taxable.multiply(BigDecimal.valueOf(request.getTaxRate())).setScale(2,
            RoundingMode.HALF_UP);
        BigDecimal grandTotal = taxable.add(taxAmount).add(sale.getDeliveryCharge()).add(sale.getOtherCharge());
        sale.setSubtotal(subtotal);
        sale.setDiscountAmount(discount);
        sale.setTaxRate(request.getTaxRate());
        sale.setTaxAmount(taxAmount);
        sale.setGrandTotal(grandTotal);
        sale.setTotalAmount(grandTotal);
        sale.setPaidAmount(BigDecimal.ZERO);
        sale.setChangeAmount(BigDecimal.ZERO);
        sale.setNote(request.getNote());
        sale.setOrderMode(request.getOrderMode());
        sale.setDeliveryRecipientName(request.getDeliveryRecipientName());
        sale.setDeliveryPhone(request.getDeliveryPhone());
        sale.setDeliveryAddress(request.getDeliveryAddress());
        sale.setDeliveryLandmark(request.getDeliveryLandmark());
        sale.setDeliveryNote(request.getDeliveryNote());
        sale.setExchangeRateKhr(currentKhrExchangeRate());

        Sale saved = saleRepository.save(sale);
        persistInvoiceDiscount(saved, discount);
        return toResponse(saved);
    }

    @Transactional
    public SaleDtos.SaleResponse hold(Long id) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        if ("PAID".equals(sale.getStatus()) || "VOID".equals(sale.getStatus()) || "REFUNDED".equals(sale.getStatus())
                || "CREDIT".equals(sale.getStatus())) {
            throw new ApiException("Cannot hold finalized sale");
        }
        sale.setStatus("HOLD");
        return toResponse(saleRepository.save(sale));
    }

    @Transactional
    public SaleDtos.SaleResponse resume(Long id) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        if (!"HOLD".equals(sale.getStatus())) {
            throw new ApiException("Sale is not on hold");
        }
        sale.setStatus("DRAFT");
        return toResponse(saleRepository.save(sale));
    }

    @Transactional
    public SaleDtos.SaleResponse update(Long id, SaleDtos.SaleCreateRequest request) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        if (sale.getPaidAmount() != null && sale.getPaidAmount().compareTo(BigDecimal.ZERO) > 0) {
            throw new ApiException("Sale cannot be edited after payment has started");
        }
        if ("PAID".equals(sale.getStatus()) || "VOID".equals(sale.getStatus()) || "REFUNDED".equals(sale.getStatus())
                || "PARTIALLY_REFUNDED".equals(sale.getStatus()) || "CREDIT".equals(sale.getStatus())) {
            throw new ApiException("Sale cannot be edited after payment has started");
        }
        sale.setDisplayName(trimToNull(request.getDisplayName()));
        if (request.getCustomerId() != null) {
            sale.setCustomer(customerRepository.findById(request.getCustomerId()).orElse(null));
        } else {
            sale.setCustomer(null);
        }
        sale.setOrderDate(parseDateOrDefault(request.getOrderDate(), sale.getOrderDate() != null ? sale.getOrderDate() : LocalDate.now()));
        sale.setDeliveryDate(parseDate(request.getDeliveryDate()));
        sale.setPaymentTerms(resolvePaymentTerms(request.getPaymentTerms(), sale.getCustomer()));
        sale.setDeliveryCharge(safeAmount(request.getDeliveryCharge()));
        sale.setOtherCharge(safeAmount(request.getOtherCharge()));
        sale.setDepositAmount(safeAmount(request.getDepositAmount()));
        sale.getLines().clear();
        List<SaleLine> lines = request.getLines().stream().map(lineReq -> {
            Product product = productRepository.findById(lineReq.getProductId())
                    .orElseThrow(() -> new ApiException("Product not found"));
            BigDecimal unitPrice = resolveUnitPrice(lineReq, product, sale.getCustomer())
                .add(modifierPriceDelta(lineReq.getModifierData()));
            SaleLine line = new SaleLine();
            line.setSale(sale);
            line.setProduct(product);
            line.setQuantity(lineReq.getQuantity());
            line.setUnitPrice(unitPrice);
            line.setLineDiscount(lineReq.getLineDiscount() == null ? BigDecimal.ZERO : lineReq.getLineDiscount());
            line.setLineNote(lineReq.getNote());
            line.setModifierSummary(lineReq.getModifierSummary());
            line.setModifierData(lineReq.getModifierData());
            BigDecimal lineTotal = unitPrice.multiply(lineReq.getQuantity())
                    .subtract(line.getLineDiscount());
            line.setLineTotal(lineTotal);
            return line;
        }).collect(Collectors.toList());
        sale.getLines().clear();
        sale.getLines().addAll(lines);
        // Skip stock validation for estimates (they don't deduct stock)
        if (sale.getStatus() == null || !sale.getStatus().startsWith("ESTIMATE")) {
            validateSaleStockAvailable(sale);
        }

        BigDecimal subtotal = lines.stream().map(SaleLine::getLineTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal discount = request.getInvoiceDiscount() == null ? BigDecimal.ZERO : request.getInvoiceDiscount();
        BigDecimal taxable = subtotal.subtract(discount);
        BigDecimal taxAmount = taxable.multiply(BigDecimal.valueOf(request.getTaxRate())).setScale(2,
                RoundingMode.HALF_UP);
        BigDecimal grandTotal = taxable.add(taxAmount).add(sale.getDeliveryCharge()).add(sale.getOtherCharge());
        sale.setSubtotal(subtotal);
        sale.setDiscountAmount(discount);
        sale.setTaxRate(request.getTaxRate());
        sale.setTaxAmount(taxAmount);
        sale.setGrandTotal(grandTotal);
        sale.setTotalAmount(grandTotal);
        sale.setNote(request.getNote());
        sale.setOrderMode(request.getOrderMode());
        sale.setDeliveryRecipientName(request.getDeliveryRecipientName());
        sale.setDeliveryPhone(request.getDeliveryPhone());
        sale.setDeliveryAddress(request.getDeliveryAddress());
        sale.setDeliveryLandmark(request.getDeliveryLandmark());
        sale.setDeliveryNote(request.getDeliveryNote());

        // Preserve estimate expiry date on update
        if (request.getEstimateExpiryDate() != null) {
            LocalDate expiry = parseDate(request.getEstimateExpiryDate());
            if (expiry != null) {
                sale.setEstimateExpiryDate(expiry);
            }
        }

        Sale saved = saleRepository.save(sale);
        persistInvoiceDiscount(saved, discount);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public SaleDtos.SaleResponse getById(Long id) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        return toResponse(sale);
    }

    @Transactional
    public SaleDtos.SaleResponse voidSale(Long id, String reason) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        sale.setStatus("VOID");
        if (reason != null && !reason.isBlank()) {
            sale.setNote(reason);
        }
        Sale saved = saleRepository.save(sale);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SALE_VOID", "Sale", String.valueOf(saved.getId()), null, saved);
        return toResponse(saved);
    }

    @Transactional
    public SaleDtos.SaleResponse deleteSale(Long id, String reason) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        sale.setStatus("VOID");
        String deleteReason = reason != null && !reason.isBlank() ? reason : "Deleted by user";
        sale.setNote(deleteReason);
        Sale saved = saleRepository.save(sale);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SALE_DELETE", "Sale", String.valueOf(saved.getId()), null, saved);
        return toResponse(saved);
    }

    @Transactional
    public SaleDtos.SaleResponse pay(Long id, SaleDtos.PayRequest request) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        Shift paymentShift = resolveShiftForSaleProcessing(sale);
        if ("VOID".equals(sale.getStatus())) {
            throw new ApiException("Cannot pay voided sale");
        }
        if ("CREDIT".equals(sale.getStatus())) {
            throw new ApiException("Cannot pay credit sale");
        }
        if ("PAID".equals(sale.getStatus()) || sale.getPaidAmount().compareTo(sale.getGrandTotal()) >= 0) {
            return toResponse(sale);
        }
        validateSaleStockAvailable(sale);
        BigDecimal remainingBeforePayment = sale.getGrandTotal().subtract(sale.getPaidAmount());
        BigDecimal requestTotal = BigDecimal.ZERO;
        BigDecimal nonCashTotal = BigDecimal.ZERO;
        for (SaleDtos.PaymentRequest pr : request.getPayments()) {
            String normalizedMethod = normalizePaymentMethod(pr.getMethod());
            BigDecimal amount = pr.getAmount() == null ? BigDecimal.ZERO : pr.getAmount();
            if (amount.compareTo(BigDecimal.ZERO) <= 0) {
                throw new ApiException("Payment amount must be greater than zero");
            }
            requestTotal = requestTotal.add(amount);
            if (!"CASH".equals(normalizedMethod)) {
                nonCashTotal = nonCashTotal.add(amount);
            }
        }
        if (requestTotal.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("At least one payment amount is required");
        }
        if (nonCashTotal.compareTo(remainingBeforePayment) > 0) {
            throw new ApiException("Non-cash payment cannot exceed the remaining balance");
        }
        BigDecimal appliedAmount = requestTotal.min(remainingBeforePayment);
        BigDecimal changeAmount = requestTotal.subtract(appliedAmount);

        for (SaleDtos.PaymentRequest pr : request.getPayments()) {
            Payment payment = new Payment();
            payment.setSale(sale);
            payment.setShift(paymentShift);
            payment.setStore(resolveSaleStore(sale));
            payment.setMethod(normalizePaymentMethod(pr.getMethod()));
            payment.setPaymentMethod(toPaymentEnum(pr.getMethod()));
            payment.setAmount(pr.getAmount());
            payment.setStatus(Payment.PaymentStatus.COMPLETED);
            Payment savedPayment = paymentRepository.save(payment);
            if (savedPayment.getReferenceNumber() == null || savedPayment.getReferenceNumber().isBlank()) {
                savedPayment.setReferenceNumber(DocumentNumberUtil.paymentReference(savedPayment));
                paymentRepository.save(savedPayment);
            }
        }
        sale.setPaidAmount(sale.getPaidAmount().add(appliedAmount));
        if (sale.getShift() == null && paymentShift != null) {
            sale.setShift(paymentShift);
        }
        sale.setChangeAmount(changeAmount);
        if (sale.getPaidAmount().compareTo(sale.getGrandTotal()) >= 0) {
            sale.setStatus("PAID");
            sale.setPaidAt(Instant.now());
            if (!sale.isStockApplied()) {
                applyStockForSale(sale);
                sale.setStockApplied(true);
            }
        }
        Sale saved = saleRepository.save(sale);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SALE_PAYMENT", "Sale", String.valueOf(saved.getId()), null, saved);
        BigDecimal cashPaid = request.getPayments().stream()
                .filter(pr -> "CASH".equalsIgnoreCase(pr.getMethod()))
                .map(SaleDtos.PaymentRequest::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal netCash = cashPaid.subtract(changeAmount);
        if (netCash.compareTo(BigDecimal.ZERO) > 0) {
            cashEventService.recordInternal(
                    saved.getShift(),
                    "SALE_CASH",
                    netCash,
                    "Cash payment",
                    saved,
                    actor);
        }
        return toResponse(saved);
    }

    @Transactional
    public SaleDtos.SaleResponse credit(Long id) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        Shift processingShift = resolveShiftForSaleProcessing(sale);
        if ("VOID".equals(sale.getStatus()) || "REFUNDED".equals(sale.getStatus())) {
            throw new ApiException("Cannot credit voided or refunded sale");
        }
        if ("PAID".equals(sale.getStatus())) {
            throw new ApiException("Sale is already paid");
        }
        if ("CREDIT".equals(sale.getStatus())) {
            throw new ApiException("Sale is already on credit");
        }
        Customer customer = sale.getCustomer();
        if (customer == null) {
            throw new ApiException("Customer is required for credit sale");
        }
        BigDecimal creditAmount = sale.getGrandTotal().subtract(sale.getPaidAmount());
        if (creditAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("No remaining balance to credit");
        }

        enforceCreditLimit(customer, creditAmount);
        validateSaleStockAvailable(sale);

        BigDecimal currentBalance = customer.getCreditBalance() == null ? BigDecimal.ZERO : customer.getCreditBalance();
        BigDecimal nextBalance = currentBalance.add(creditAmount);

        customer.setCreditBalance(nextBalance);
        customerRepository.save(customer);
        CustomerCreditAccount account = creditAccountRepository.findByCustomerId(customer.getId()).orElse(null);
        if (account == null) {
            account = new CustomerCreditAccount();
            account.setCustomer(customer);
        }
        account.setBalance(nextBalance);
        account.setCreditLimit(customer.getCreditLimit());
        creditAccountRepository.save(account);

        Instant now = Instant.now();
        int termDays = parseCreditTermDays(sale.getPaymentTerms());
        sale.setCreditIssuedAt(now);
        sale.setCreditDueAt(now.plus(termDays, ChronoUnit.DAYS));
        sale.setCreditTermDays(termDays);
        sale.setStatus("CREDIT");
        if (sale.getShift() == null && processingShift != null) {
            sale.setShift(processingShift);
        }
        if (!sale.isStockApplied()) {
            applyStockForSale(sale);
            sale.setStockApplied(true);
        }
        Sale saved = saleRepository.save(sale);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SALE_CREDIT", "Sale", String.valueOf(saved.getId()), null, saved);
        return toResponse(saved);
    }

    @Transactional
    public SaleDtos.SaleResponse confirmInvoice(Long id) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        if ("VOID".equals(sale.getStatus()) || "REFUNDED".equals(sale.getStatus())) {
            throw new ApiException("Cannot confirm voided or refunded sale");
        }
        Sale saved = finalizeInvoiceState(sale);
        if (saved.getCustomer() != null) {
            creditCollectionService.syncBalanceForCustomer(saved.getCustomer().getId());
        }
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SALE_CONFIRM", "Sale", String.valueOf(saved.getId()), null, saved);
        return toResponse(saved);
    }

    @Transactional
    public int migrateLegacyConfirmedHolds() {
        List<Sale> legacySales = saleRepository.findLegacyConfirmedHolds();
        java.util.Set<Long> affectedCustomerIds = new java.util.HashSet<>();
        int migrated = 0;
        for (Sale sale : legacySales) {
            finalizeInvoiceState(sale);
            if (sale.getCustomer() != null && sale.getCustomer().getId() != null) {
                affectedCustomerIds.add(sale.getCustomer().getId());
            }
            migrated++;
        }
        affectedCustomerIds.forEach(creditCollectionService::syncBalanceForCustomer);
        return migrated;
    }

    private int parseCreditTermDays(String paymentTerms) {
        if (paymentTerms == null || paymentTerms.isBlank()) return 0;
        String normalized = paymentTerms.trim().toUpperCase(Locale.ROOT);
        if ("CASH".equals(normalized)) return 0;
        if ("CREDIT".equals(normalized)) return 30;
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("(\\d+)").matcher(paymentTerms);
        if (m.find()) { try { return Integer.parseInt(m.group(1)); } catch (NumberFormatException ignored) {} }
        return 30;
    }

    private Sale finalizeInvoiceState(Sale sale) {
        BigDecimal remaining = sale.getGrandTotal().subtract(sale.getPaidAmount());
        validateSaleStockAvailable(sale);
        if (remaining.compareTo(BigDecimal.ZERO) <= 0) {
            sale.setStatus("PAID");
            if (sale.getPaidAt() == null) {
                sale.setPaidAt(Instant.now());
            }
            if (!sale.isStockApplied()) {
                applyStockForSale(sale);
            }
            if (sale.getSaleNumber() == null) {
                sale.setSaleNumber(DocumentNumberUtil.saleReceiptNumber(sale));
            }
            return saleRepository.save(sale);
        }

        Customer customer = sale.getCustomer();
        if (customer == null) {
            throw new ApiException("Customer is required to confirm an invoice with an outstanding balance");
        }

        int termDays = parseCreditTermDays(sale.getPaymentTerms());
        LocalDate baseDate = sale.getOrderDate() != null ? sale.getOrderDate() : LocalDate.now();
        Instant dueAt = baseDate.plusDays(Math.max(0, termDays))
                .atTime(LocalTime.MAX)
                .atZone(ZoneId.systemDefault())
                .toInstant();

        sale.setCreditIssuedAt(sale.getCreditIssuedAt() != null ? sale.getCreditIssuedAt() : Instant.now());
        sale.setCreditTermDays(termDays);
        sale.setCreditDueAt(dueAt);
        if (sale.getSaleNumber() == null) {
            sale.setSaleNumber(DocumentNumberUtil.saleNumber(sale));
        }
        sale.setStatus("CREDIT");
        if (!sale.isStockApplied()) {
            applyStockForSale(sale);
        }
        return saleRepository.save(sale);
    }

    @Transactional
    public SaleDtos.SaleResponse refund(Long id, SaleDtos.RefundRequest request) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        if (!"PAID".equals(sale.getStatus()) && !"PARTIALLY_REFUNDED".equals(sale.getStatus())) {
            throw new ApiException("Only paid sales can be refunded");
        }
        BigDecimal refundAmount = request.getAmount() != null ? request.getAmount() : calculateRefundAmount(sale, request);
        if (refundAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("Refund amount must be greater than zero");
        }
        if (refundAmount.compareTo(sale.getPaidAmount()) > 0) {
            throw new ApiException("Refund exceeds paid amount");
        }
        Shift refundShift = resolveShiftForSaleProcessing(sale);
        boolean approvalRequired = requiresRefundApproval(sale, request, refundAmount);
        User approvingManager = approvalRequired ? verifyRefundApproval(request) : null;
        Payment payment = new Payment();
        payment.setSale(sale);
        payment.setCustomer(sale.getCustomer());
        payment.setShift(refundShift);
        payment.setStore(resolveSaleStore(sale));
        payment.setMethod(normalizePaymentMethod(request.getMethod()));
        payment.setPaymentMethod(toPaymentEnum(request.getMethod()));
        payment.setStatus(Payment.PaymentStatus.REFUNDED);
        payment.setNotes(buildRefundNotes(request, approvingManager));
        payment.setAmount(refundAmount.negate());
        paymentRepository.save(payment);
        if (sale.getShift() == null && refundShift != null) {
            sale.setShift(refundShift);
        }
        sale.setPaidAmount(sale.getPaidAmount().subtract(refundAmount));
        boolean fullRefund = sale.getPaidAmount().compareTo(BigDecimal.ZERO) <= 0
                || refundAmount.compareTo(sale.getGrandTotal()) >= 0;
        if (fullRefund) {
            sale.setStatus("REFUNDED");
            applyReturnStock(sale, request.getLines());
        } else {
            sale.setStatus("PARTIALLY_REFUNDED");
            applyReturnStock(sale, request.getLines());
        }
        Sale saved = saleRepository.save(sale);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SALE_REFUND", "Sale", String.valueOf(saved.getId()), null,
                buildRefundAuditPayload(saved, refundAmount, approvalRequired, approvingManager));
        if ("CASH".equalsIgnoreCase(request.getMethod())) {
            cashEventService.recordInternal(
                    saved.getShift(),
                    "REFUND_CASH",
                    refundAmount.negate(),
                    request.getReason() != null ? request.getReason() : "Cash refund",
                    saved,
                    actor);
        }
        return toResponse(saved);
    }

    private boolean requiresRefundApproval(Sale sale, SaleDtos.RefundRequest request, BigDecimal refundAmount) {
        boolean fullSaleRefund = refundAmount.compareTo(sale.getGrandTotal()) >= 0
                || refundAmount.compareTo(sale.getPaidAmount()) >= 0;
        boolean nonCashRefund = !"CASH".equalsIgnoreCase(normalizePaymentMethod(request.getMethod()));
        boolean highValueRefund = refundAmount.compareTo(REFUND_APPROVAL_THRESHOLD) >= 0;
        boolean manualAmountRefund = request.getLines() == null || request.getLines().isEmpty();
        return Boolean.TRUE.equals(request.getForceApproval())
                || fullSaleRefund
                || nonCashRefund
                || highValueRefund
                || manualAmountRefund;
    }

    private User verifyRefundApproval(SaleDtos.RefundRequest request) {
        if (request.getManagerEmail() == null || request.getManagerEmail().isBlank()) {
            throw new ApiException("Manager email is required for this refund");
        }
        if (request.getManagerPassword() == null || request.getManagerPassword().isBlank()) {
            throw new ApiException("Manager password is required for this refund");
        }
        User manager = userRepository.findByEmail(request.getManagerEmail())
                .orElseThrow(() -> new ApiException("Manager not found"));
        boolean isManager = manager.getRoles().stream()
                .anyMatch(r -> "MANAGER".equals(r.getName()) || "OWNER".equals(r.getName()) || "ADMIN".equals(r.getName()));
        if (!isManager) {
            throw new ApiException("User does not have manager privileges");
        }
        if (!passwordEncoder.matches(request.getManagerPassword(), manager.getPasswordHash())) {
            throw new ApiException("Invalid manager credentials");
        }
        return manager;
    }

    private String buildRefundNotes(SaleDtos.RefundRequest request, User approvingManager) {
        StringBuilder note = new StringBuilder();
        if (request.getReason() != null && !request.getReason().isBlank()) {
            note.append(request.getReason().trim());
        }
        if (approvingManager != null) {
            if (note.length() > 0) {
                note.append(" | ");
            }
            note.append("Approved by ").append(approvingManager.getEmail());
            if (request.getApprovalReason() != null && !request.getApprovalReason().isBlank()) {
                note.append(" (").append(request.getApprovalReason().trim()).append(")");
            }
        }
        return note.length() == 0 ? null : note.toString();
    }

    private String buildRefundAuditPayload(Sale sale, BigDecimal refundAmount, boolean approvalRequired, User approvingManager) {
        StringBuilder audit = new StringBuilder();
        audit.append("Refund amount=").append(refundAmount);
        audit.append(", status=").append(sale.getStatus());
        if (approvalRequired) {
            audit.append(", approvalRequired=true");
        }
        if (approvingManager != null) {
            audit.append(", approvedBy=").append(approvingManager.getEmail());
        }
        return audit.toString();
    }

    @Transactional
    public SaleDtos.SaleResponse repayCreditSale(Long id, SaleDtos.CreditRepaymentRequest request) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        Shift paymentShift = resolveShiftForSaleProcessing(sale);
        if (!"CREDIT".equals(sale.getStatus())) {
            throw new ApiException("Only credit sales can be repaid");
        }
        if (request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("Repayment amount must be greater than zero");
        }
        Customer customer = sale.getCustomer();
        if (customer == null) {
            throw new ApiException("Customer is required for credit repayment");
        }

        BigDecimal remaining = sale.getGrandTotal().subtract(sale.getPaidAmount());
        if (request.getAmount().compareTo(remaining) > 0) {
            throw new ApiException("Repayment exceeds remaining balance");
        }

        Payment payment = new Payment();
        payment.setSale(sale);
        payment.setCustomer(customer);
        payment.setShift(paymentShift);
        payment.setStore(resolveSaleStore(sale));
        payment.setMethod(normalizePaymentMethod(request.getMethod()));
        payment.setPaymentMethod(toPaymentEnum(request.getMethod()));
        payment.setAmount(request.getAmount());
        payment.setNotes(request.getNotes());
        payment.setStatus(Payment.PaymentStatus.COMPLETED);
        paymentRepository.save(payment);

        sale.setPaidAmount(sale.getPaidAmount().add(request.getAmount()));
        if (sale.getShift() == null && paymentShift != null) {
            sale.setShift(paymentShift);
        }
        if (sale.getPaidAmount().compareTo(sale.getGrandTotal()) >= 0) {
            sale.setStatus("PAID");
        }
        Sale saved = saleRepository.save(sale);

        // Record allocation so this repayment appears in the credit ledger
        CustomerCreditAllocation allocation = new CustomerCreditAllocation();
        allocation.setPayment(payment);
        allocation.setCustomer(customer);
        allocation.setTargetType(CustomerCreditAllocation.TargetType.SALE);
        allocation.setSale(saved);
        allocation.setAmount(request.getAmount());
        allocation.setNote(request.getNotes());
        creditAllocationRepository.save(allocation);

        // Recalculate balance from live data instead of manual subtraction
        creditCollectionService.syncBalanceForCustomer(customer.getId());

        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SALE_REPAYMENT", "Sale", String.valueOf(saved.getId()), null, saved);
        return toResponse(saved);
    }

    private void applyStockForSale(Sale sale) {
        for (SaleLine line : sale.getLines()) {
            BigDecimal remainingToDeduct = remainingStockToDeduct(line);
            if (remainingToDeduct.compareTo(BigDecimal.ZERO) <= 0) {
                continue;
            }
            if (isAssembledBundle(line.getProduct())) {
                for (ProductBundleComponent component : line.getProduct().getBundleComponents()) {
                    if (!component.getComponentProduct().isTrackInventory()) {
                        continue;
                    }
                    applyStockMovement(sale, component.getComponentProduct(),
                            remainingToDeduct.multiply(component.getComponentQuantity()), "SALE", "Bundle sale");
                }
                line.setStockDeductedQuantity(safeLineQuantity(line.getStockDeductedQuantity()).add(remainingToDeduct));
                continue;
            }
            // Skip inventory update if product doesn't track inventory
            if (!line.getProduct().isTrackInventory()) {
                line.setStockDeductedQuantity(safeLineQuantity(line.getStockDeductedQuantity()).add(remainingToDeduct));
                continue;
            }
            applyStockMovement(sale, line.getProduct(), remainingToDeduct, "SALE", "Sale");
            line.setStockDeductedQuantity(safeLineQuantity(line.getStockDeductedQuantity()).add(remainingToDeduct));
        }
        sale.setStockApplied(isStockFullyDeducted(sale));
    }

    private void validateSaleStockAvailable(Sale sale) {
        Store store = resolveSaleStore(sale);
        Map<Long, RequiredStock> requiredByProduct = new LinkedHashMap<>();
        for (SaleLine line : sale.getLines()) {
            BigDecimal remainingToDeduct = remainingStockToDeduct(line);
            if (remainingToDeduct.compareTo(BigDecimal.ZERO) <= 0) {
                continue;
            }
            if (isAssembledBundle(line.getProduct())) {
                for (ProductBundleComponent component : line.getProduct().getBundleComponents()) {
                    Product componentProduct = component.getComponentProduct();
                    if (!componentProduct.isTrackInventory()) {
                        continue;
                    }
                    BigDecimal requiredQty = remainingToDeduct.multiply(component.getComponentQuantity());
                    addRequiredStock(requiredByProduct, componentProduct, requiredQty);
                }
                continue;
            }
            if (!line.getProduct().isTrackInventory()) {
                continue;
            }
            addRequiredStock(requiredByProduct, line.getProduct(), remainingToDeduct);
        }
        for (RequiredStock required : requiredByProduct.values()) {
            BigDecimal requiredStockQty = toStockUnitQuantity(required.product(), required.quantity());
            StockItem stockItem = stockItemRepository
                    .findByProductIdAndStoreIdForUpdate(required.product().getId(), store.getId())
                    .orElseThrow(() -> new ApiException(insufficientStockMessage(required.product(), BigDecimal.ZERO, required.quantity())));
            BigDecimal available = stockItem.getQuantity() == null ? BigDecimal.ZERO : stockItem.getQuantity();
            if (available.compareTo(requiredStockQty) < 0) {
                throw new ApiException(insufficientStockMessage(required.product(), available, required.quantity()));
            }
        }
    }

    private void addRequiredStock(Map<Long, RequiredStock> requiredByProduct, Product product, BigDecimal quantity) {
        requiredByProduct.compute(product.getId(), (id, existing) -> {
            if (existing == null) {
                return new RequiredStock(product, quantity);
            }
            return new RequiredStock(existing.product(), existing.quantity().add(quantity));
        });
    }

    private String insufficientStockMessage(Product product, BigDecimal availableStockQty, BigDecimal requestedSaleQty) {
        BigDecimal availableSaleQty = fromStockUnitQuantity(product, availableStockQty == null ? BigDecimal.ZERO : availableStockQty);
        return "Insufficient stock for " + productDisplayName(product)
                + ". Available: " + formatQuantity(availableSaleQty)
                + ", requested: " + formatQuantity(requestedSaleQty == null ? BigDecimal.ZERO : requestedSaleQty);
    }

    private String productDisplayName(Product product) {
        return firstNonBlank(product.getNameEn(), product.getNameKm(), product.getSku(), "product #" + product.getId());
    }

    private BigDecimal fromStockUnitQuantity(Product product, BigDecimal stockQuantity) {
        BigDecimal safeStockQuantity = stockQuantity == null ? BigDecimal.ZERO : stockQuantity;
        if (!product.isTrackInventory()) {
            return safeStockQuantity;
        }
        Unit saleUnit = product.getSaleUnit();
        Unit stockUnit = product.getStockUnit();
        if (saleUnit == null || stockUnit == null) {
            return safeStockQuantity;
        }
        if (saleUnit.getId() != null && saleUnit.getId().equals(stockUnit.getId())) {
            return safeStockQuantity;
        }
        if (saleUnit.getBaseUnitGroup() == null || stockUnit.getBaseUnitGroup() == null
                || !saleUnit.getBaseUnitGroup().equalsIgnoreCase(stockUnit.getBaseUnitGroup())) {
            return safeStockQuantity;
        }
        BigDecimal saleFactor = normalizedUnitFactor(saleUnit);
        BigDecimal stockFactor = normalizedUnitFactor(stockUnit);
        if (saleFactor.compareTo(BigDecimal.ZERO) <= 0 || stockFactor.compareTo(BigDecimal.ZERO) <= 0) {
            return safeStockQuantity;
        }
        return safeStockQuantity.multiply(stockFactor)
                .divide(saleFactor, 3, RoundingMode.HALF_UP)
                .stripTrailingZeros();
    }

    private String formatQuantity(BigDecimal quantity) {
        return (quantity == null ? BigDecimal.ZERO : quantity)
                .stripTrailingZeros()
                .toPlainString();
    }

    private record RequiredStock(Product product, BigDecimal quantity) {
    }

    private void applyReturnStock(Sale sale, List<SaleDtos.RefundLineRequest> refundLines) {
        if (refundLines == null || refundLines.isEmpty()) {
            return;
        }
        java.util.Map<Long, BigDecimal> lineQuantities = new java.util.HashMap<>();
        for (SaleDtos.RefundLineRequest refundLine : refundLines) {
            if (refundLine.getQuantity() == null || refundLine.getQuantity().compareTo(BigDecimal.ZERO) <= 0) {
                throw new ApiException("Refund quantity must be greater than zero");
            }
            lineQuantities.merge(refundLine.getSaleLineId(), refundLine.getQuantity(), BigDecimal::add);
        }
        for (SaleLine line : sale.getLines()) {
            BigDecimal returnQty = lineQuantities.getOrDefault(line.getId(), BigDecimal.ZERO);
            if (returnQty.compareTo(BigDecimal.ZERO) <= 0) {
                continue;
            }
            BigDecimal alreadyRefunded = line.getRefundedQuantity() == null ? BigDecimal.ZERO : line.getRefundedQuantity();
            BigDecimal refundableQty = line.getQuantity().subtract(alreadyRefunded);
            if (returnQty.compareTo(refundableQty) > 0) {
                throw new ApiException("Refund quantity exceeds remaining sold quantity");
            }
            if (isAssembledBundle(line.getProduct())) {
                for (ProductBundleComponent component : line.getProduct().getBundleComponents()) {
                    if (!component.getComponentProduct().isTrackInventory()) {
                        continue;
                    }
                    reverseStockMovement(line.getProduct(), component.getComponentProduct(),
                            returnQty.multiply(component.getComponentQuantity()), "RETURN", "Bundle refund", sale);
                }
                line.setRefundedQuantity(alreadyRefunded.add(returnQty));
                reduceStockDeductedQuantity(line, returnQty);
                continue;
            }
            // Skip inventory update if product doesn't track inventory
            if (!line.getProduct().isTrackInventory()) {
                line.setRefundedQuantity(alreadyRefunded.add(returnQty));
                reduceStockDeductedQuantity(line, returnQty);
                continue;
            }
            reverseStockMovement(line.getProduct(), line.getProduct(), returnQty, "RETURN", "Refund", sale);
            line.setRefundedQuantity(alreadyRefunded.add(returnQty));
            reduceStockDeductedQuantity(line, returnQty);
        }
        sale.setStockApplied(isStockFullyDeducted(sale));
    }

    private boolean isAssembledBundle(Product product) {
        return "BUNDLE".equals(product.getProductType()) && "ASSEMBLED_ON_SALE".equals(product.getBundleMode());
    }

    private void applyStockMovement(Sale sale, Product product, BigDecimal quantity, String type, String reason) {
        Store store = resolveSaleStore(sale);
        StockItem item = stockItemRepository.findByProductIdAndStoreIdForUpdate(product.getId(), store.getId())
                .orElseThrow(() -> new ApiException(insufficientStockMessage(product, BigDecimal.ZERO, quantity)));
        BigDecimal stockQuantity = toStockUnitQuantity(product, quantity);
        BigDecimal newQty = item.getQuantity().subtract(stockQuantity);
        if (newQty.compareTo(BigDecimal.ZERO) < 0) {
            throw new ApiException(insufficientStockMessage(product, item.getQuantity(), quantity));
        }
        item.setQuantity(newQty);
        stockItemRepository.save(item);
        StockMovement movement = new StockMovement();
        movement.setProduct(product);
        movement.setStore(store);
        movement.setMovementType(type);
        movement.setQuantity(stockQuantity.negate());
        movement.setReason(movementReason(reason, sale, null));
        movement.setCreatedBy(SecurityUtil.currentUsername());
        stockMovementRepository.save(movement);
    }

    private void reverseStockMovement(Product sourceProduct, Product product, BigDecimal quantity, String type, String reason, Sale sale) {
        Store store = resolveSaleStore(sale);
        StockItem item = stockItemRepository.findByProductIdAndStoreId(product.getId(), store.getId())
                .orElseGet(() -> {
                    StockItem s = new StockItem();
                    s.setProduct(product);
                    s.setStore(store);
                    s.setQuantity(BigDecimal.ZERO);
                    s.setLowStockThreshold(product.getLowStockThreshold());
                    return stockItemRepository.save(s);
                });
        BigDecimal stockQuantity = toStockUnitQuantity(product, quantity);
        item.setQuantity(item.getQuantity().add(stockQuantity));
        stockItemRepository.save(item);
        StockMovement movement = new StockMovement();
        movement.setProduct(product);
        movement.setStore(store);
        movement.setMovementType(type);
        movement.setQuantity(stockQuantity);
        String sourceProductName = sourceProduct != null && !sourceProduct.getId().equals(product.getId())
                ? sourceProduct.getNameEn()
                : null;
        movement.setReason(movementReason(reason, sale, sourceProductName));
        movement.setCreatedBy(SecurityUtil.currentUsername());
        stockMovementRepository.save(movement);
    }

    private String movementReason(String reason, Sale sale, String sourceProductName) {
        StringBuilder text = new StringBuilder(reason);
        if (sourceProductName != null && !sourceProductName.isBlank()) {
            text.append(" - ").append(sourceProductName);
        }
        String reference = sale.getSaleNumber() != null && !sale.getSaleNumber().isBlank()
                ? sale.getSaleNumber()
                : sale.getId() != null ? "sale#" + sale.getId() : null;
        if (reference != null) {
            text.append(" [").append(reference).append(']');
        }
        return text.toString();
    }

    private BigDecimal remainingStockToDeduct(SaleLine line) {
        return line.getQuantity().subtract(safeLineQuantity(line.getStockDeductedQuantity()));
    }

    private void reduceStockDeductedQuantity(SaleLine line, BigDecimal quantity) {
        BigDecimal nextValue = safeLineQuantity(line.getStockDeductedQuantity()).subtract(quantity);
        if (nextValue.compareTo(BigDecimal.ZERO) < 0) {
            nextValue = BigDecimal.ZERO;
        }
        line.setStockDeductedQuantity(nextValue);
    }

    private boolean isStockFullyDeducted(Sale sale) {
        return sale.getLines().stream().allMatch(line -> {
            if (isAssembledBundle(line.getProduct()) || line.getProduct().isTrackInventory()) {
                return remainingStockToDeduct(line).compareTo(BigDecimal.ZERO) <= 0;
            }
            return true;
        });
    }

    private BigDecimal safeLineQuantity(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }

    private BigDecimal toStockUnitQuantity(Product product, BigDecimal saleQuantity) {
        BigDecimal safeSaleQuantity = saleQuantity == null ? BigDecimal.ZERO : saleQuantity;
        if (!product.isTrackInventory()) {
            return safeSaleQuantity;
        }
        Unit saleUnit = product.getSaleUnit();
        Unit stockUnit = product.getStockUnit();
        if (saleUnit == null || stockUnit == null) {
            return safeSaleQuantity;
        }
        if (saleUnit.getId() != null && saleUnit.getId().equals(stockUnit.getId())) {
            return safeSaleQuantity;
        }
        if (saleUnit.getBaseUnitGroup() == null || stockUnit.getBaseUnitGroup() == null
                || !saleUnit.getBaseUnitGroup().equalsIgnoreCase(stockUnit.getBaseUnitGroup())) {
            return safeSaleQuantity;
        }
        BigDecimal saleFactor = normalizedUnitFactor(saleUnit);
        BigDecimal stockFactor = normalizedUnitFactor(stockUnit);
        if (saleFactor.compareTo(BigDecimal.ZERO) <= 0 || stockFactor.compareTo(BigDecimal.ZERO) <= 0) {
            return safeSaleQuantity;
        }
        return safeSaleQuantity.multiply(saleFactor)
                .divide(stockFactor, 3, RoundingMode.HALF_UP)
                .stripTrailingZeros();
    }

    private BigDecimal normalizedUnitFactor(Unit unit) {
        if (unit == null || unit.getConversionFactor() == null || unit.getConversionFactor().compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ONE;
        }
        return unit.getConversionFactor();
    }

    private boolean isEstimateStatus(String status) {
        return status != null && status.toUpperCase(Locale.ROOT).startsWith("ESTIMATE");
    }

    // ── Estimate/Quotation methods ───────────────────────────────────────────

    @Transactional
    public SaleDtos.SaleResponse createEstimate(SaleDtos.SaleCreateRequest request) {
        Sale sale = new Sale();
        sale.setStatus("ESTIMATE");
        sale.setClientRef(request.getClientRef());
        sale.setDisplayName(trimToNull(request.getDisplayName()));
        sale.setCreatedBy(userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow());

        if (request.getCustomerId() != null) {
            sale.setCustomer(customerRepository.findById(request.getCustomerId()).orElse(null));
        }

        sale.setOrderDate(parseDateOrDefault(request.getOrderDate(), LocalDate.now()));
        sale.setDeliveryDate(parseDate(request.getDeliveryDate()));
        sale.setPaymentTerms(resolvePaymentTerms(request.getPaymentTerms(), sale.getCustomer()));
        sale.setDeliveryCharge(safeAmount(request.getDeliveryCharge()));
        sale.setOtherCharge(safeAmount(request.getOtherCharge()));
        sale.setDepositAmount(safeAmount(request.getDepositAmount()));

        // Parse estimate expiry (default 30 days)
        LocalDate expiry = parseDate(request.getEstimateExpiryDate());
        if (expiry == null) {
            expiry = LocalDate.now().plusDays(30);
        }
        sale.setEstimateExpiryDate(expiry);

        List<SaleLine> lines = request.getLines().stream().map(lineReq -> {
            Product product = productRepository.findById(lineReq.getProductId())
                .orElseThrow(() -> new ApiException("Product not found"));
            BigDecimal unitPrice = resolveUnitPrice(lineReq, product, sale.getCustomer())
                .add(modifierPriceDelta(lineReq.getModifierData()));
            SaleLine line = new SaleLine();
            line.setSale(sale);
            line.setProduct(product);
            line.setQuantity(lineReq.getQuantity());
            line.setUnitPrice(unitPrice);
            line.setLineDiscount(lineReq.getLineDiscount() == null ? BigDecimal.ZERO : lineReq.getLineDiscount());
            line.setLineNote(lineReq.getNote());
            line.setModifierSummary(lineReq.getModifierSummary());
            line.setModifierData(lineReq.getModifierData());
            BigDecimal lineTotal = unitPrice.multiply(lineReq.getQuantity())
                .subtract(line.getLineDiscount());
            line.setLineTotal(lineTotal);
            return line;
        }).collect(Collectors.toList());
        sale.getLines().clear();
        sale.getLines().addAll(lines);

        BigDecimal subtotal = lines.stream().map(SaleLine::getLineTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal discount = request.getInvoiceDiscount() == null ? BigDecimal.ZERO : request.getInvoiceDiscount();
        BigDecimal taxable = subtotal.subtract(discount);
        BigDecimal taxAmount = taxable.multiply(BigDecimal.valueOf(request.getTaxRate())).setScale(2, RoundingMode.HALF_UP);
        BigDecimal grandTotal = taxable.add(taxAmount).add(sale.getDeliveryCharge()).add(sale.getOtherCharge());
        sale.setSubtotal(subtotal);
        sale.setDiscountAmount(discount);
        sale.setTaxRate(request.getTaxRate());
        sale.setTaxAmount(taxAmount);
        sale.setGrandTotal(grandTotal);
        sale.setTotalAmount(grandTotal);
        sale.setPaidAmount(BigDecimal.ZERO);
        sale.setChangeAmount(BigDecimal.ZERO);
        sale.setNote(request.getNote());
        sale.setOrderMode(request.getOrderMode());
        sale.setDeliveryRecipientName(request.getDeliveryRecipientName());
        sale.setDeliveryPhone(request.getDeliveryPhone());
        sale.setDeliveryAddress(request.getDeliveryAddress());
        sale.setDeliveryLandmark(request.getDeliveryLandmark());
        sale.setDeliveryNote(request.getDeliveryNote());

        // Estimates do NOT deduct stock
        Sale saved = saleRepository.save(sale);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "ESTIMATE_CREATE", "Sale", String.valueOf(saved.getId()), null, saved);
        return toResponse(saved);
    }

    @Transactional
    public SaleDtos.SaleResponse sendEstimate(Long id) {
        Sale sale = saleRepository.findById(id)
                .orElseThrow(() -> new ApiException("Estimate not found"));
        if (!isEstimateStatus(sale.getStatus())) {
            throw new ApiException("Only estimates can be sent");
        }
        if ("ESTIMATE_SENT".equals(sale.getStatus())) {
            return toResponse(sale); // already sent — idempotent
        }
        if (!"ESTIMATE".equals(sale.getStatus()) && !"ESTIMATE_SENT".equals(sale.getStatus())) {
            throw new ApiException("Only draft estimates can be sent");
        }

        sale.setStatus("ESTIMATE_SENT");
        sale.setEstimateSentAt(Instant.now());
        Sale saved = saleRepository.save(sale);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "ESTIMATE_SENT", "Sale", String.valueOf(id), null, saved);

        // Generate PDF and email if customer has email
        if (saved.getCustomer() != null && saved.getCustomer().getEmail() != null
                && !saved.getCustomer().getEmail().isBlank()) {
            try {
                byte[] pdf = generateEstimatePdf(saved);
                emailService.sendEstimate(
                    saved.getCustomer().getEmail(),
                    saved.getCustomer().getDisplayName(),
                    toResponse(saved),
                    pdf);
            } catch (Exception e) {
                // Log but don't fail — estimate was still sent
                log.warn("Failed to email estimate {}: {}", saved.getId(), e.getMessage());
            }
        }

        return toResponse(saved);
    }

    @Transactional
    public SaleDtos.SaleResponse acceptEstimate(Long id) {
        Sale sale = saleRepository.findById(id)
                .orElseThrow(() -> new ApiException("Estimate not found"));
        if (!"ESTIMATE_SENT".equals(sale.getStatus())) {
            throw new ApiException("Only sent estimates can be accepted");
        }
        sale.setStatus("ESTIMATE_ACCEPTED");
        sale.setEstimateAcceptedAt(Instant.now());
        Sale saved = saleRepository.save(sale);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "ESTIMATE_ACCEPTED", "Sale", String.valueOf(id), null, saved);
        return toResponse(saved);
    }

    @Transactional
    public SaleDtos.SaleResponse declineEstimate(Long id, String reason) {
        Sale sale = saleRepository.findById(id)
                .orElseThrow(() -> new ApiException("Estimate not found"));
        if (!isEstimateStatus(sale.getStatus()) || "ESTIMATE_ACCEPTED".equals(sale.getStatus())
                || "ESTIMATE_DECLINED".equals(sale.getStatus())) {
            throw new ApiException("Estimate cannot be declined in its current state");
        }
        sale.setStatus("ESTIMATE_DECLINED");
        sale.setEstimateDeclinedAt(Instant.now());
        sale.setEstimateDeclineReason(reason);
        Sale saved = saleRepository.save(sale);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "ESTIMATE_DECLINED", "Sale", String.valueOf(id), reason, saved);
        return toResponse(saved);
    }

    @Transactional
    public SaleDtos.SaleResponse convertEstimateToSale(Long id) {
        Sale estimate = saleRepository.findById(id)
                .orElseThrow(() -> new ApiException("Estimate not found"));
        if (!"ESTIMATE_ACCEPTED".equals(estimate.getStatus())) {
            throw new ApiException("Only accepted estimates can be converted to a sale");
        }

        // Create new Sale from estimate data
        Sale sale = new Sale();
        sale.setStatus("DRAFT");
        sale.setDisplayName(estimate.getDisplayName());
        sale.setCustomer(estimate.getCustomer());
        sale.setCreatedBy(estimate.getCreatedBy());
        sale.setOrderDate(LocalDate.now());
        sale.setDeliveryDate(estimate.getDeliveryDate());
        sale.setPaymentTerms(estimate.getPaymentTerms());
        sale.setDeliveryCharge(estimate.getDeliveryCharge());
        sale.setOtherCharge(estimate.getOtherCharge());
        sale.setDepositAmount(estimate.getDepositAmount());
        sale.setNote(estimate.getNote());
        sale.setOrderMode(estimate.getOrderMode());
        sale.setDeliveryRecipientName(estimate.getDeliveryRecipientName());
        sale.setDeliveryPhone(estimate.getDeliveryPhone());
        sale.setDeliveryAddress(estimate.getDeliveryAddress());
        sale.setDeliveryLandmark(estimate.getDeliveryLandmark());
        sale.setDeliveryNote(estimate.getDeliveryNote());
        sale.setConvertedFromEstimateId(estimate.getId());

        // Copy line items
        List<SaleLine> lines = estimate.getLines().stream().map(el -> {
            SaleLine line = new SaleLine();
            line.setSale(sale);
            line.setProduct(el.getProduct());
            line.setQuantity(el.getQuantity());
            line.setUnitPrice(el.getUnitPrice());
            line.setLineDiscount(el.getLineDiscount());
            line.setLineTotal(el.getLineTotal());
            line.setLineNote(el.getLineNote());
            line.setModifierSummary(el.getModifierSummary());
            line.setModifierData(el.getModifierData());
            return line;
        }).collect(Collectors.toList());
        sale.getLines().clear();
        sale.getLines().addAll(lines);

        sale.setSubtotal(estimate.getSubtotal());
        sale.setDiscountAmount(estimate.getDiscountAmount());
        sale.setTaxRate(estimate.getTaxRate());
        sale.setTaxAmount(estimate.getTaxAmount());
        sale.setGrandTotal(estimate.getGrandTotal());
        sale.setTotalAmount(estimate.getGrandTotal());
        sale.setPaidAmount(BigDecimal.ZERO);
        sale.setChangeAmount(BigDecimal.ZERO);
        sale.setClientRef(null); // don't reuse clientRef
        sale.setExchangeRateKhr(currentKhrExchangeRate());

        Sale saved = saleRepository.save(sale);

        // Mark estimate as converted
        estimate.setStatus("ESTIMATE_CONVERTED");
        saleRepository.save(estimate);

        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "ESTIMATE_CONVERTED", "Sale", String.valueOf(estimate.getId()),
                "Converted to sale #" + saved.getId(), saved);
        auditService.log(actor, "SALE_CREATE_FROM_ESTIMATE", "Sale", String.valueOf(saved.getId()),
                "Created from estimate #" + estimate.getId(), saved);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public List<SaleDtos.SaleResponse> listEstimates(String status) {
        List<Sale> sales;
        if (status != null && !status.isBlank()) {
            sales = saleRepository.findEstimatesByStatus(status);
        } else {
            sales = saleRepository.findEstimates();
        }
        return sales.stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public byte[] estimatePdf(Long id) {
        Sale sale = saleRepository.findById(id)
                .orElseThrow(() -> new ApiException("Estimate not found"));
        if (!isEstimateStatus(sale.getStatus())) {
            throw new ApiException("Not an estimate");
        }
        return generateEstimatePdf(sale);
    }

    private byte[] generateEstimatePdf(Sale sale) {
        String html = buildEstimateHtml(sale);
        return pdfService.renderHtmlToPdf(html);
    }

    private String buildEstimateHtml(Sale sale) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='utf-8'>")
          .append("<style>")
          .append("body{font-family: sans-serif; margin:40px; color:#333;}")
          .append(".header{display:flex; justify-content:space-between; margin-bottom:40px;}")
          .append(".estimate-badge{font-size:24px; font-weight:bold; color:#6366f1; border:2px solid #6366f1; display:inline-block; padding:4px 16px; border-radius:6px;}")
          .append(".status-badge{padding:4px 12px; border-radius:4px; font-size:12px; font-weight:bold; text-transform:uppercase;}")
          .append(".status-ESTIMATE{background:#e0e7ff; color:#4338ca;}")
          .append(".status-ESTIMATE_SENT{background:#fef3c7; color:#b45309;}")
          .append(".status-ESTIMATE_ACCEPTED{background:#d1fae5; color:#047857;}")
          .append("table{width:100%; border-collapse:collapse; margin-top:20px;}")
          .append("th{background:#f8fafc; text-align:left; padding:8px 12px; border-bottom:2px solid #e2e8f0; font-size:13px; text-transform:uppercase; color:#64748b;}")
          .append("td{padding:8px 12px; border-bottom:1px solid #e2e8f0; font-size:14px;}")
          .append(".totals{text-align:right; margin-top:20px;}")
          .append(".totals table{width:300px; margin-left:auto;}")
          .append(".totals td{padding:6px 12px;}")
          .append(".totals .grand-total{font-size:18px; font-weight:bold; color:#1e293b;}")
          .append(".footer{margin-top:60px; font-size:12px; color:#94a3b8; text-align:center; border-top:1px solid #e2e8f0; padding-top:20px;}")
          .append(".expiry-notice{background:#fef3c7; border:1px solid #f59e0b; border-radius:6px; padding:12px; margin:20px 0; font-size:13px;}")
          .append("</style></head><body>");

        // Header
        sb.append("<div class='header'>")
          .append("<div><div class='estimate-badge'>ESTIMATE</div>")
          .append("<p style='margin-top:8px; color:#64748b;'># ").append(escapeHtml(DocumentNumberUtil.estimateNumber(sale))).append("</p></div>")
          .append("<div style='text-align:right;'><h2 style='margin:0;'>KAKNNEA POS</h2>")
          .append("<p style='margin:4px 0; color:#64748b;'>Date: ").append(sale.getCreatedAt() != null ? sale.getCreatedAt().toString().substring(0, 10) : "").append("</p>")
          .append("</div></div>");

        // Status badge
        sb.append("<div><span class='status-badge status-").append(escapeHtml(sale.getStatus())).append("'>")
          .append(escapeHtml(sale.getStatus())).append("</span></div>");

        // Expiry notice
        if (sale.getEstimateExpiryDate() != null) {
            sb.append("<div class='expiry-notice'>This estimate expires on ")
              .append(sale.getEstimateExpiryDate().toString())
              .append("</div>");
        }

        // Customer info
        if (sale.getCustomer() != null) {
            sb.append("<div style='margin:20px 0;'><strong>").append(escapeHtml(sale.getCustomer().getDisplayName())).append("</strong>");
            if (sale.getCustomer().getPhone() != null) {
                sb.append("<br/>").append(escapeHtml(sale.getCustomer().getPhone()));
            }
            sb.append("</div>");
        }

        // Line items table
        sb.append("<table><thead><tr><th>Item</th><th>Qty</th><th>Price</th><th>Discount</th><th style='text-align:right'>Total</th></tr></thead><tbody>");
        for (SaleLine line : sale.getLines()) {
            sb.append("<tr>")
              .append("<td>").append(escapeHtml(line.getProduct().getNameEn())).append("</td>")
              .append("<td>").append(line.getQuantity().stripTrailingZeros().toPlainString()).append("</td>")
              .append("<td>$").append(line.getUnitPrice().setScale(2).toPlainString()).append("</td>")
              .append("<td>$").append(line.getLineDiscount().setScale(2).toPlainString()).append("</td>")
              .append("<td style='text-align:right'>$").append(line.getLineTotal().setScale(2).toPlainString()).append("</td>")
              .append("</tr>");
        }
        sb.append("</tbody></table>");

        // Totals
        sb.append("<div class='totals'><table>")
          .append("<tr><td>Subtotal</td><td>$").append(sale.getSubtotal().setScale(2).toPlainString()).append("</td></tr>");
        if (sale.getDiscountAmount().compareTo(BigDecimal.ZERO) > 0) {
            sb.append("<tr><td>Discount</td><td>-$").append(sale.getDiscountAmount().setScale(2).toPlainString()).append("</td></tr>");
        }
        if (sale.getDeliveryCharge().compareTo(BigDecimal.ZERO) > 0) {
            sb.append("<tr><td>Delivery</td><td>$").append(sale.getDeliveryCharge().setScale(2).toPlainString()).append("</td></tr>");
        }
        if (sale.getTaxRate() > 0) {
            sb.append("<tr><td>Tax (").append(String.format("%.1f", sale.getTaxRate() * 100)).append("%)</td><td>$")
              .append(sale.getTaxAmount().setScale(2).toPlainString()).append("</td></tr>");
        }
        sb.append("<tr class='grand-total'><td><strong>Total</strong></td><td><strong>$")
          .append(sale.getGrandTotal().setScale(2).toPlainString()).append("</strong></td></tr>")
          .append("</table></div>");

        // Footer
        sb.append("<div class='footer'>")
          .append("<p>This is an estimate, not an invoice. Prices are valid until the expiry date shown above.</p>")
          .append("<p>KAKNNEA POS — Thank you for your business!</p>")
          .append("</div>");

        sb.append("</body></html>");
        return sb.toString();
    }

    private String escapeHtml(String value) {
        if (value == null) return "";
        return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }

    private SaleDtos.SaleResponse toResponse(Sale sale) {
        SaleDtos.SaleResponse resp = new SaleDtos.SaleResponse();
        resp.setId(sale.getId());
        resp.setInvoiceNumber(displaySaleNumber(sale));
        resp.setStatus(sale.getStatus());
        // Set currency from business settings
        try {
            var settings = businessSettingsRepository.findFirstByOrderByIdAsc().orElse(null);
            if (settings != null) resp.setCurrency(settings.getCurrency());
        } catch (Exception ex) {
            log.warn("toResponse: failed to resolve currency from business settings for sale {}", sale.getId(), ex);
        }
        resp.setDisplayName(sale.getDisplayName());
        resp.setSubtotal(sale.getSubtotal());
        resp.setDiscountAmount(sale.getDiscountAmount());
        resp.setTaxRate(sale.getTaxRate());
        resp.setTaxAmount(sale.getTaxAmount());
        resp.setGrandTotal(sale.getGrandTotal());
        resp.setPaidAmount(sale.getPaidAmount());
        resp.setDeliveryCharge(sale.getDeliveryCharge());
        resp.setOtherCharge(sale.getOtherCharge());
        resp.setDepositAmount(sale.getDepositAmount());
        resp.setNote(sale.getNote());
        resp.setOrderDate(sale.getOrderDate() != null ? sale.getOrderDate().toString() : null);
        resp.setDeliveryDate(sale.getDeliveryDate() != null ? sale.getDeliveryDate().toString() : null);
        resp.setPaymentTerms(sale.getPaymentTerms());
        resp.setCreditDueAt(sale.getCreditDueAt() != null ? sale.getCreditDueAt().toString() : null);
        resp.setCustomerId(sale.getCustomer() != null ? sale.getCustomer().getId() : null);
        resp.setCustomerName(sale.getCustomer() != null ? firstNonBlank(sale.getCustomer().getDisplayName(), sale.getCustomer().getNameEn(), sale.getCustomer().getNameKm()) : null);
        resp.setTableId(sale.getTable() != null ? sale.getTable().getId() : null);
        resp.setTableNumber(sale.getTable() != null ? sale.getTable().getTableNumber() : null);
        resp.setCashierName(sale.getCreatedBy() != null ? sale.getCreatedBy().getFullName() : null);
        resp.setShiftId(sale.getShift() != null ? sale.getShift().getId() : null);
        resp.setCreatedAt(sale.getCreatedAt() != null ? sale.getCreatedAt().toString() : null);
        resp.setEndDate(sale.getUpdatedAt() != null ? sale.getUpdatedAt().toString() : null);
        resp.setOrderMode(sale.getOrderMode());
        resp.setDeliveryRecipientName(sale.getDeliveryRecipientName());
        resp.setDeliveryPhone(sale.getDeliveryPhone());
        resp.setDeliveryAddress(sale.getDeliveryAddress());
        resp.setDeliveryLandmark(sale.getDeliveryLandmark());
        resp.setDeliveryNote(sale.getDeliveryNote());
        // ── Estimate fields ──
        resp.setEstimateExpiryDate(sale.getEstimateExpiryDate() != null ? sale.getEstimateExpiryDate().toString() : null);
        resp.setEstimateSentAt(sale.getEstimateSentAt() != null ? sale.getEstimateSentAt().toString() : null);
        resp.setEstimateAcceptedAt(sale.getEstimateAcceptedAt() != null ? sale.getEstimateAcceptedAt().toString() : null);
        resp.setEstimateDeclinedAt(sale.getEstimateDeclinedAt() != null ? sale.getEstimateDeclinedAt().toString() : null);
        resp.setEstimateDeclineReason(sale.getEstimateDeclineReason());
        resp.setConvertedFromEstimateId(sale.getConvertedFromEstimateId());
        resp.setIsEstimate(isEstimateStatus(sale.getStatus()));
        resp.setLines(sale.getLines().stream().map(line -> {
            SaleDtos.SaleLineResponse lr = new SaleDtos.SaleLineResponse();
            lr.setId(line.getId());
            lr.setProductId(line.getProduct().getId());
            lr.setProductNameEn(line.getProduct().getNameEn());
            lr.setProductNameKm(line.getProduct().getNameKm());
            lr.setQuantity(line.getQuantity());
            lr.setUnitPrice(line.getUnitPrice());
            lr.setLineDiscount(line.getLineDiscount());
            lr.setLineTotal(line.getLineTotal());
            lr.setNote(line.getLineNote());
            lr.setModifierSummary(line.getModifierSummary());
            lr.setModifierData(line.getModifierData());
            return lr;
        }).collect(Collectors.toList()));
        resp.setPayments(paymentRepository.findBySaleIdOrderByCreatedAtAscIdAsc(sale.getId()).stream().map(payment -> {
            SaleDtos.PaymentSummary summary = new SaleDtos.PaymentSummary();
            summary.setId(payment.getId());
            summary.setMethod(payment.getMethod());
            summary.setAmount(payment.getAmount());
            summary.setStatus(payment.getStatus() != null ? payment.getStatus().name() : null);
            return summary;
        }).collect(Collectors.toList()));
        return resp;
    }

    private String displaySaleNumber(Sale sale) {
        return isSaleReceiptSale(sale)
                ? DocumentNumberUtil.saleReceiptNumber(sale)
                : DocumentNumberUtil.saleNumber(sale);
    }

    private boolean isSaleReceiptSale(Sale sale) {
        if (sale == null) {
            return false;
        }
        String status = sale.getStatus() == null ? "" : sale.getStatus().toUpperCase(Locale.ROOT);
        String terms = sale.getPaymentTerms() == null ? "" : sale.getPaymentTerms().toUpperCase(Locale.ROOT);
        boolean receiptSource = sale.getShift() != null || "CASH".equals(terms);
        if (!receiptSource || "CREDIT".equals(status) || "DRAFT".equals(status) || "HOLD".equals(status)) {
            return false;
        }
        if ("REFUNDED".equals(status) || "PARTIALLY_REFUNDED".equals(status) || "VOID".equals(status)) {
            return true;
        }
        BigDecimal paid = sale.getPaidAmount() == null ? BigDecimal.ZERO : sale.getPaidAmount();
        BigDecimal total = sale.getGrandTotal() == null ? BigDecimal.ZERO : sale.getGrandTotal();
        return paid.compareTo(BigDecimal.ZERO) > 0 && paid.compareTo(total) >= 0;
    }

    @Transactional(readOnly = true)
    public java.util.List<SaleDtos.SaleResponse> listByStatus(String status) {
        return saleRepository.findByStatusOrderByCreatedAtDesc(status).stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public java.util.List<SaleDtos.SaleResponse> listAll() {
        return saleRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public java.util.List<SaleDtos.SaleResponse> listByShift(Long shiftId, String status) {
        if (status != null && !status.isBlank()) {
            return saleRepository.findByShiftIdAndStatusOrderByCreatedAtDesc(shiftId, status).stream()
                    .map(this::toResponse)
                    .collect(Collectors.toList());
        } else {
            return saleRepository.findByShiftIdOrderByCreatedAtDesc(shiftId).stream()
                    .map(this::toResponse)
                    .collect(Collectors.toList());
        }
    }

    @Transactional(readOnly = true)
    public java.util.List<SaleDtos.SaleResponse> listFiltered(
            Long shiftId,
            String status,
            Instant dateFrom,
            Instant dateTo,
            String query) {
        String normalizedStatus = (status == null || status.isBlank()) ? null : status;
        String normalizedQuery = (query == null || query.isBlank()) ? null : query.trim();
        return saleRepository.findFiltered(shiftId, normalizedStatus, dateFrom, dateTo).stream()
                .filter(sale -> matchesQuery(sale, normalizedQuery))
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * Resolve the unit price for a sale line.
     * Priority: 1) explicit unitPrice from request, 2) price list match by customer type, 3) product base price.
     * Also enforces minimum order quantity when a price list rule applies.
     */
    private BigDecimal resolveUnitPrice(SaleDtos.SaleLineRequest lineReq, Product product, Customer customer) {
        BigDecimal requested = lineReq.getUnitPrice();
        if (requested != null && requested.compareTo(BigDecimal.ZERO) > 0) {
            return requested; // explicit override — skip price list
        }
        if (customer != null) {
            PriceListService.PriceResolution resolution =
                    priceListService.resolvePriceForCustomer(customer, product.getId(), Instant.now());
            if (resolution != null) {
                if (resolution.minimumOrderQty() != null
                        && lineReq.getQuantity().compareTo(resolution.minimumOrderQty()) < 0) {
                    throw new ApiException("Minimum order quantity for " + product.getNameEn()
                            + " is " + resolution.minimumOrderQty().stripTrailingZeros().toPlainString());
                }
                return resolution.price();
            }
        }
        BigDecimal basePrice = product.getPrice();
        if (basePrice == null || basePrice.compareTo(BigDecimal.ZERO) == 0) {
            throw new ApiException("No price configured for product: " + product.getNameEn());
        }
        return basePrice;
    }

    /**
     * Sums the `priceDelta` of every selected modifier option stored in a line's
     * `modifierData` (the JSON array `[{groupId,groupName,optionId,optionName,priceDelta}]`
     * the POS cart sends — see CartItem.modifierDataJson on the frontend). Returns
     * ZERO for null/blank/unparseable data so a malformed value never blocks a sale.
     */
    private BigDecimal modifierPriceDelta(String modifierDataJson) {
        if (modifierDataJson == null || modifierDataJson.isBlank()) {
            return BigDecimal.ZERO;
        }
        try {
            JsonNode node = MODIFIER_MAPPER.readTree(modifierDataJson);
            BigDecimal total = BigDecimal.ZERO;
            if (node.isArray()) {
                for (JsonNode option : node) {
                    if (option.hasNonNull("priceDelta")) {
                        total = total.add(BigDecimal.valueOf(option.get("priceDelta").asDouble()));
                    }
                }
            }
            return total;
        } catch (Exception e) {
            log.warn("Could not parse modifierData for pricing: {}", e.getMessage());
            return BigDecimal.ZERO;
        }
    }

    /**
     * Enforce credit hold flag and credit limit before allowing a credit sale.
     * A customer with creditLimit = 0 is treated as "unlimited credit".
     */
    private void enforceCreditLimit(Customer customer, BigDecimal additionalAmount) {
        if (customer == null) return;
        if (customer.isCreditHold()) {
            throw new ApiException("Customer is on credit hold — new credit sales are blocked");
        }
        BigDecimal limit = customer.getCreditLimit() == null ? BigDecimal.ZERO : customer.getCreditLimit();
        if (limit.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal current = customer.getCreditBalance() == null ? BigDecimal.ZERO : customer.getCreditBalance();
            if (current.add(additionalAmount).compareTo(limit) > 0) {
                throw new ApiException("CREDIT_LIMIT_EXCEEDED: adding "
                        + additionalAmount.setScale(2, RoundingMode.HALF_UP)
                        + " would exceed credit limit of " + limit.setScale(2, RoundingMode.HALF_UP));
            }
        }
    }

    private boolean matchesQuery(Sale sale, String query) {
        if (query == null) {
            return true;
        }
        String needle = query.toLowerCase(Locale.ROOT);
        if (containsIgnoreCase(sale.getSaleNumber(), needle)) {
            return true;
        }
        if (sale.getId() != null && sale.getId().toString().contains(query)) {
            return true;
        }
        if (sale.getCreatedBy() != null && containsIgnoreCase(sale.getCreatedBy().getFullName(), needle)) {
            return true;
        }
        return sale.getCustomer() != null && containsIgnoreCase(sale.getCustomer().getNameEn(), needle);
    }

    private BigDecimal safeAmount(BigDecimal value) {
        return value == null || value.compareTo(BigDecimal.ZERO) < 0 ? BigDecimal.ZERO : value;
    }

    private boolean containsIgnoreCase(String value, String needleLower) {
        return value != null && value.toLowerCase(Locale.ROOT).contains(needleLower);
    }

    private LocalDate parseDate(String rawDate) {
        if (rawDate == null || rawDate.isBlank()) {
            return null;
        }
        try {
            return LocalDate.parse(rawDate.trim());
        } catch (Exception ex) {
            throw new ApiException("Invalid date value");
        }
    }

    private LocalDate parseDateOrDefault(String rawDate, LocalDate fallback) {
        LocalDate parsed = parseDate(rawDate);
        return parsed != null ? parsed : fallback;
    }

    private String resolvePaymentTerms(String requestedTerms, Customer customer) {
        String normalized = trimToNull(requestedTerms);
        if (normalized != null) {
            return normalized;
        }
        return customer != null ? trimToNull(customer.getPaymentTerms()) : null;
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return null;
    }

    private void ensureEditable(Sale sale) {
        // Sale edits are intentionally allowed from the admin transaction forms.
        // Payment, refund, and ledger history remains attached for audit.
    }

    private Shift resolveShiftForSaleProcessing(Sale sale) {
        Shift currentShift = findCurrentShiftForActor();
        if (sale.getShift() != null) {
            return sale.getShift();
        }
        if (currentShift != null) {
            return currentShift;
        }
        if (isShiftRequiredForSales()) {
            throw new ApiException("Open a shift before processing sales");
        }
        return null;
    }

    private Shift findCurrentShiftForActor() {
        User actor = userRepository.findByEmail(SecurityUtil.currentUsername())
                .orElseThrow(() -> new ApiException("User not found"));
        return shiftRepository.findFirstByOpenedByIdAndStatusOrderByOpenedAtDesc(actor.getId(), "OPEN")
                .orElse(null);
    }

    private boolean isShiftRequiredForSales() {
        return businessSettingsRepository.findFirstByOrderByIdAsc()
                .map(BusinessSettings::isRequireShiftForSales)
                .orElse(true);
    }

    private String normalizePaymentMethod(String rawMethod) {
        if (rawMethod == null || rawMethod.isBlank()) {
            throw new ApiException("Payment method is required");
        }
        String method = rawMethod.trim().toUpperCase(Locale.US);
        return switch (method) {
            case "KHQR", "ABA_KHQR" -> "KHQR";
            case "ABA", "ABA_PAY" -> "ABA";
            case "WING" -> "WING";
            case "CARD", "CREDIT_CARD", "DEBIT_CARD" -> "CARD";
            case "BANK_TRANSFER" -> "BANK_TRANSFER";
            case "CASH" -> "CASH";
            default -> throw new ApiException("Unsupported payment method: " + rawMethod);
        };
    }

    private Payment.PaymentMethod toPaymentEnum(String method) {
        return switch (normalizePaymentMethod(method)) {
            case "KHQR" -> Payment.PaymentMethod.KHQR;
            case "ABA" -> Payment.PaymentMethod.ABA;
            case "WING" -> Payment.PaymentMethod.WING;
            case "CARD" -> Payment.PaymentMethod.CARD;
            case "BANK_TRANSFER" -> Payment.PaymentMethod.BANK_TRANSFER;
            default -> Payment.PaymentMethod.CASH;
        };
    }

    private Store resolveSaleStore(Sale sale) {
        if (sale.getShift() != null && sale.getShift().getStore() != null) {
            return sale.getShift().getStore();
        }
        return storeRepository.findAll().stream().findFirst()
                .orElseThrow(() -> new ApiException("No store configured"));
    }

    private void persistInvoiceDiscount(Sale sale, BigDecimal discount) {
        sale.getDiscounts().clear();
        if (discount == null || discount.compareTo(BigDecimal.ZERO) <= 0)
            return;
        SaleDiscount d = new SaleDiscount();
        d.setSale(sale);
        d.setDiscountType("INVOICE");
        d.setAmount(discount);
        sale.getDiscounts().add(d);
        saleDiscountRepository.save(d);
    }

    private BigDecimal calculateRefundAmount(Sale sale, SaleDtos.RefundRequest request) {
        if (request.getLines() == null || request.getLines().isEmpty()) {
            return BigDecimal.ZERO;
        }
        BigDecimal total = BigDecimal.ZERO;
        java.util.Map<Long, SaleLine> saleLines = sale.getLines().stream()
                .collect(Collectors.toMap(SaleLine::getId, line -> line));
        for (SaleDtos.RefundLineRequest lineRequest : request.getLines()) {
            SaleLine line = saleLines.get(lineRequest.getSaleLineId());
            if (line == null) {
                throw new ApiException("Refund line not found on sale");
            }
            if (lineRequest.getQuantity().compareTo(line.getQuantity()) > 0) {
                throw new ApiException("Refund quantity exceeds sold quantity");
            }
            BigDecimal alreadyRefunded = line.getRefundedQuantity() == null ? BigDecimal.ZERO : line.getRefundedQuantity();
            BigDecimal refundableQty = line.getQuantity().subtract(alreadyRefunded);
            if (lineRequest.getQuantity().compareTo(refundableQty) > 0) {
                throw new ApiException("Refund quantity exceeds remaining sold quantity");
            }
            BigDecimal proportionalLineTotal = line.getLineTotal()
                    .divide(line.getQuantity(), 4, RoundingMode.HALF_UP)
                    .multiply(lineRequest.getQuantity())
                    .setScale(2, RoundingMode.HALF_UP);
            total = total.add(proportionalLineTotal);
        }
        return total;
    }

    private BigDecimal refundedQuantityForLine(SaleLine line, Sale sale) {
        return line.getRefundedQuantity() == null ? BigDecimal.ZERO : line.getRefundedQuantity();
    }

    private BigDecimal totalRefundedAmount(Sale sale) {
        return paymentRepository.findBySaleIdOrderByCreatedAtAscIdAsc(sale.getId()).stream()
                .map(Payment::getAmount)
                .filter(amount -> amount != null && amount.compareTo(BigDecimal.ZERO) < 0)
                .map(BigDecimal::abs)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    @Transactional(readOnly = true)
    public com.kaknnea.pos.dto.ReceiptDtos.ReceiptResponse receipt(Long id) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Sale not found"));
        var settings = businessSettingsRepository.findAll().stream().findFirst().orElse(null);
        com.kaknnea.pos.dto.ReceiptDtos.ReceiptResponse resp = new com.kaknnea.pos.dto.ReceiptDtos.ReceiptResponse();
        if (settings != null) {
            resp.setBusinessName(settings.getBusinessName());
            resp.setAddress(settings.getAddress());
            resp.setPhone(settings.getPhone());
            resp.setCurrency(settings.getCurrency());
            resp.setFooter(settings.getReceiptFooter());
            resp.setLogoUrl(settings.getLogoUrl());
        }
        resp.setSaleId(sale.getId());
        resp.setSaleNumber(displaySaleNumber(sale));
        resp.setShiftId(sale.getShift() != null ? sale.getShift().getId() : null);
        resp.setStoreId(sale.getShift() != null && sale.getShift().getStore() != null ? sale.getShift().getStore().getId() : null);
        resp.setStoreName(sale.getShift() != null && sale.getShift().getStore() != null ? sale.getShift().getStore().getName() : null);
        resp.setCreatedAt(sale.getCreatedAt() != null ? sale.getCreatedAt().toString() : null);
        resp.setCashierName(sale.getCreatedBy() != null ? sale.getCreatedBy().getFullName() : null);
        if (sale.getCustomer() != null) {
            resp.setCustomerName(sale.getCustomer().getNameEn());
            resp.setCustomerPhone(sale.getCustomer().getPhone());
        }
        if (sale.getTable() != null) {
            resp.setTableId(sale.getTable().getId());
            resp.setTableNumber(sale.getTable().getTableNumber());
        }
        resp.setOrderMode(sale.getOrderMode());
        resp.setDeliveryRecipientName(sale.getDeliveryRecipientName());
        resp.setDeliveryPhone(sale.getDeliveryPhone());
        resp.setDeliveryAddress(sale.getDeliveryAddress());
        resp.setDeliveryLandmark(sale.getDeliveryLandmark());
        resp.setDeliveryNote(sale.getDeliveryNote());
        resp.setSubtotal(sale.getSubtotal());
        resp.setTaxAmount(sale.getTaxAmount());
        resp.setDiscountAmount(sale.getDiscountAmount());
        resp.setDeliveryCharge(sale.getDeliveryCharge());
        resp.setOtherCharge(sale.getOtherCharge());
        resp.setTotal(sale.getGrandTotal());
        resp.setPaidAmount(sale.getPaidAmount());
        resp.setChangeAmount(sale.getChangeAmount());
        resp.setRefundedAmount(totalRefundedAmount(sale));
        resp.setStatus(sale.getStatus());
        resp.setExchangeRateKhr(sale.getExchangeRateKhr());
        resp.setQrImageData(buildQrImageData(sale.getId(), 180));
        applyReceiptBalanceSummary(resp, sale);
        resp.setLines(sale.getLines().stream().map(line -> {
            com.kaknnea.pos.dto.ReceiptDtos.ReceiptLine rl = new com.kaknnea.pos.dto.ReceiptDtos.ReceiptLine();
            rl.setSaleLineId(line.getId());
            rl.setNameEn(line.getProduct().getNameEn());
            rl.setNameKm(line.getProduct().getNameKm());
            rl.setQty(line.getQuantity());
            if (line.getProduct().getSaleUnit() != null) {
                rl.setUnitSymbol(line.getProduct().getSaleUnit().getSymbol());
            }
            rl.setUnitPrice(line.getUnitPrice());
            rl.setModifierAmount(modifierPriceDelta(line.getModifierData()));
            rl.setLineTotal(line.getLineTotal());
            rl.setRefundedQty(refundedQuantityForLine(line, sale));
            rl.setModifierSummary(line.getModifierSummary());
            return rl;
        }).collect(java.util.stream.Collectors.toList()));
        resp.setPayments(paymentRepository.findBySaleIdOrderByCreatedAtAscIdAsc(sale.getId()).stream().map(payment -> {
            com.kaknnea.pos.dto.ReceiptDtos.ReceiptPayment receiptPayment = new com.kaknnea.pos.dto.ReceiptDtos.ReceiptPayment();
            receiptPayment.setMethod(payment.getMethod());
            receiptPayment.setAmount(payment.getAmount());
            return receiptPayment;
        }).collect(Collectors.toList()));
        return resp;
    }

    private void applyReceiptBalanceSummary(com.kaknnea.pos.dto.ReceiptDtos.ReceiptResponse resp, Sale sale) {
        Customer customer = sale.getCustomer();
        if (customer == null) {
            return;
        }

        BigDecimal saleTotal = sale.getGrandTotal() == null ? BigDecimal.ZERO : sale.getGrandTotal();
        BigDecimal paidAmount = sale.getPaidAmount() == null ? BigDecimal.ZERO : sale.getPaidAmount();
        BigDecimal saleBalance = saleTotal.subtract(paidAmount).max(BigDecimal.ZERO);

        BigDecimal accountBalance = creditAccountRepository.findByCustomerId(customer.getId())
                .map(CustomerCreditAccount::getBalance)
                .orElse(customer.getCreditBalance());
        if (accountBalance == null) {
            accountBalance = BigDecimal.ZERO;
        }

        BigDecimal oldBalance = accountBalance;
        BigDecimal totalBalance = accountBalance;
        if (saleBalance.compareTo(BigDecimal.ZERO) > 0) {
            if ("CREDIT".equalsIgnoreCase(sale.getStatus()) && accountBalance.compareTo(saleBalance) >= 0) {
                oldBalance = accountBalance.subtract(saleBalance);
            } else {
                totalBalance = accountBalance.add(saleBalance);
            }
        }

        resp.setOldBalance(oldBalance.max(BigDecimal.ZERO));
        resp.setTotalBalance(totalBalance.max(BigDecimal.ZERO));
    }

    @Transactional(readOnly = true)
    public byte[] invoicePdf(Long id, Boolean thermal) {
        var receipt = receipt(id);
        String html = (thermal != null && thermal)
                ? generateThermalReceiptHtml(receipt)
                : generateStandardInvoiceHtml(receipt);
        return pdfService.renderHtmlToPdf(html);
    }

    private String generateStandardInvoiceHtml(com.kaknnea.pos.dto.ReceiptDtos.ReceiptResponse receipt) {
        String qrImage = buildQrImageData(receipt.getSaleId(), 160);
        String currency = receipt.getCurrency();
        String symbol = currencySymbol(currency);
        BigDecimal total = receipt.getTotal() == null ? BigDecimal.ZERO : receipt.getTotal();
        BigDecimal paid = receipt.getPaidAmount() == null ? BigDecimal.ZERO : receipt.getPaidAmount();
        BigDecimal balance = total.subtract(paid).max(BigDecimal.ZERO);
        boolean saleReceipt = paid.compareTo(BigDecimal.ZERO) > 0 && paid.compareTo(total) >= 0;
        String invoiceNo = receipt.getSaleNumber() == null || receipt.getSaleNumber().isBlank()
                ? String.valueOf(receipt.getSaleId())
                : receipt.getSaleNumber();
        String documentTitle = saleReceipt ? "SALE RECEIPT" : "INVOICE";
        String customerLabel = saleReceipt ? "SOLD TO" : "BILL TO";
        String numberLabel = saleReceipt ? "SALE RECEIPT#" : "INVOICE#";
        String invoiceDate = formatInvoiceDate(receipt.getCreatedAt());
        StringBuilder html = new StringBuilder();
        html.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/><style>")
                .append("@page{size:A4;margin:0;}*{box-sizing:border-box;}")
                .append("body{margin:0;background:#fff;font-family:'Noto Sans Khmer','KhmerFallback',Arial,sans-serif;font-size:12px;line-height:1.65;color:#1f2933;}")
                .append(".page{position:relative;width:210mm;min-height:297mm;padding:24mm 18mm 18mm;background:#fff;}")
                .append(".header-table{width:100%;border-collapse:collapse;margin-bottom:30mm;}")
                .append(".header-table td{border:0;padding:0;vertical-align:top;}")
                .append(".business{font-size:15px;font-weight:700;color:#111827;margin-bottom:4px;}")
                .append(".muted,.business-lines{color:#4b5563;font-size:11px;line-height:1.55;}")
                .append(".logo{text-align:right;color:#111827;font-size:28px;font-weight:700;line-height:1;}")
                .append(".intro-table{width:100%;border-collapse:collapse;margin-bottom:24mm;}")
                .append(".intro-table td{border:0;padding:0;vertical-align:top;}")
                .append("h1{margin:0 0 10px;color:#6f9bab;font-size:18px;font-weight:700;letter-spacing:.01em;}")
                .append(".label,.meta-table th{color:#88939b;font-weight:700;text-transform:uppercase;}")
                .append(".bill-name{margin-top:3px;color:#111827;font-weight:600;}")
                .append(".meta-table{width:72mm;margin:13px 0 0 auto;border-collapse:collapse;}")
                .append(".meta-table th{width:28mm;text-align:left;padding:1px 8px 1px 0;font-size:10px;line-height:1.45;}")
                .append(".meta-table td{padding:1px 0;color:#111827;font-weight:600;line-height:1.45;}")
                .append(".line-table{width:100%;border-collapse:collapse;margin-bottom:12mm;}")
                .append(".line-table thead{background:#e4f0f6;color:#6f8593;}")
                .append(".line-table th{padding:6px 7px;text-align:left;font-size:10px;font-weight:700;text-transform:uppercase;}")
                .append(".line-table td{padding:8px 7px;vertical-align:top;color:#111827;border:0;line-height:1.7;}")
                .append(".num{text-align:right;white-space:nowrap;}")
                .append(".item strong{font-weight:600;}")
                .append(".item .modifiers{display:block;color:#7b838a;font-size:9.5px;font-style:italic;margin-top:2px;}")
                .append(".after-lines{width:100%;border-collapse:collapse;margin-bottom:16mm;}")
                .append(".after-lines td{border:0;padding:0;vertical-align:top;}")
                .append(".message{width:86mm;margin-top:6mm;padding-top:9mm;border-top:1px dashed #d1d5db;color:#4b5563;font-size:10px;line-height:1.55;}")
                .append(".totals-table{width:78mm;margin-left:auto;border-collapse:collapse;}")
                .append(".totals-table td{border:0;padding:2px 0;color:#7b838a;line-height:1.35;}")
                .append(".totals-table .amount{text-align:right;color:#111827;font-weight:700;white-space:nowrap;padding-left:10mm;}")
                .append(".totals-table .balance-label,.totals-table .balance-amount{padding-top:9px;border-top:1px dashed #d1d5db;color:#5b636a;font-weight:700;}")
                .append(".totals-table .balance-amount{color:#111827;font-size:16px;}")
                .append(".payment-summary{clear:both;margin:8mm 0 10mm;padding:5mm 0;border-top:1px dashed #d1d5db;border-bottom:1px dashed #d1d5db;}")
                .append(".section-title{margin-bottom:4mm;color:#6f9bab;font-size:10px;font-weight:700;text-transform:uppercase;}")
                .append(".payment-grid{width:100%;border-collapse:collapse;margin-bottom:4mm;}")
                .append(".payment-grid td{width:33.33%;border:0;padding:0 5mm 0 0;vertical-align:top;}")
                .append(".payment-grid span{display:block;color:#88939b;font-size:9px;font-weight:700;text-transform:uppercase;}")
                .append(".payment-grid strong{display:block;color:#111827;font-weight:700;}")
                .append(".payments-table{width:100%;border-collapse:collapse;}")
                .append(".payments-table thead{background:#f0f6f8;color:#6f8593;}")
                .append(".payments-table th{padding:5px 7px;text-align:left;font-size:10px;font-weight:700;text-transform:uppercase;}")
                .append(".payments-table td{padding:5px 7px;border-top:1px solid #edf2f4;color:#111827;}")
                .append(".tax-summary{margin-top:14mm;}")
                .append(".tax-title{color:#6f9bab;font-weight:700;font-size:10px;margin-bottom:4px;}")
                .append(".tax-head,.tax-row{display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;padding:5px 7px;text-align:right;}")
                .append(".tax-head{background:#e4f0f6;color:#6f8593;font-weight:700;}")
                .append(".qr{margin-top:12mm;text-align:center;color:#4b5563;}")
                .append(".qr img{width:95px;height:95px;}")
                .append(".page-footer{position:absolute;left:0;right:0;bottom:10mm;text-align:center;color:#9ca3af;font-size:10px;}")
                .append("</style></head><body>")
                .append("<main class='page'>")
                .append("<table class='header-table'><tr><td>")
                .append("<div class='business'>").append(escapeHtml(nullToEmpty(receipt.getBusinessName()))).append("</div>")
                .append("<div class='business-lines'>")
                .append("<div>").append(escapeHtml(nullToEmpty(receipt.getAddress()))).append("</div>")
                .append("<div>").append(escapeHtml(nullToEmpty(receipt.getPhone()))).append("</div>")
                .append("</div></td><td></td></tr></table>")
                .append("<table class='intro-table'><tr><td>")
                .append("<h1>").append(documentTitle).append("</h1>")
                .append("<div class='label'>").append(customerLabel).append("</div>")
                .append("<div class='bill-name'>").append(escapeHtml(nullToEmpty(receipt.getCustomerName()))).append("</div>");
        if (receipt.getCustomerPhone() != null && !receipt.getCustomerPhone().isBlank()) {
            html.append("<div class='muted'>").append(escapeHtml(receipt.getCustomerPhone())).append("</div>");
        }
        if (receipt.getDeliveryAddress() != null && !receipt.getDeliveryAddress().isBlank()) {
            html.append("<div class='muted'>").append(escapeHtml(receipt.getDeliveryAddress())).append("</div>");
        }
        html.append("</td><td>")
                .append("<table class='meta-table'>")
                .append("<tr><th>").append(numberLabel).append("</th><td>").append(escapeHtml(invoiceNo)).append("</td></tr>")
                .append("<tr><th>DATE</th><td>").append(invoiceDate).append("</td></tr>");
        if (saleReceipt) {
            html.append("<tr><th>PAID</th><td>").append(symbol).append(formatMoney(paid, currency)).append("</td></tr>");
        } else {
            html.append("<tr><th>DUE DATE</th><td>").append(invoiceDate).append("</td></tr>");
        }
        if (receipt.getTableNumber() != null && !receipt.getTableNumber().isBlank()) {
            html.append("<tr><th>TABLE</th><td>").append(escapeHtml(receipt.getTableNumber())).append("</td></tr>");
        }
        html.append("</table></td></tr></table>")
                .append("<table class='line-table'><thead><tr><th>ITEM</th><th class='num'>QTY</th><th>UNIT</th><th class='num'>RATE</th><th class='num'>AMOUNT</th></tr></thead><tbody>");
        if (receipt.getLines() != null) {
            for (var line : receipt.getLines()) {
                String name = buildItemName(line.getNameKm(), line.getNameEn());
                html.append("<tr><td class='item'><strong>").append(escapeHtml(name)).append("</strong>");
                BigDecimal modifierAmount = line.getModifierAmount() == null ? BigDecimal.ZERO : line.getModifierAmount();
                if (modifierAmount.compareTo(BigDecimal.ZERO) != 0) {
                    BigDecimal basePrice = (line.getUnitPrice() == null ? BigDecimal.ZERO : line.getUnitPrice())
                            .subtract(modifierAmount);
                    html.append("<span class='modifiers'>Base: ").append(symbol).append(formatMoney(basePrice, currency))
                            .append(" + Modifier: ").append(symbol).append(formatMoney(modifierAmount, currency))
                            .append("</span>");
                }
                if (line.getModifierSummary() != null && !line.getModifierSummary().isBlank()) {
                    html.append("<span class='modifiers'>").append(escapeHtml(line.getModifierSummary())).append("</span>");
                }
                html.append("</td>")
                        .append("<td class='num'>").append(formatQuantity(line.getQty())).append("</td>")
                        .append("<td>").append(escapeHtml(line.getUnitSymbol())).append("</td>")
                        .append("<td class='num'>").append(symbol).append(formatMoney(line.getUnitPrice(), currency)).append("</td>")
                        .append("<td class='num'>").append(symbol).append(formatMoney(line.getLineTotal(), currency))
                        .append("</td></tr>");
            }
        }
        html.append("</tbody></table>")
                .append("<table class='after-lines'><tr><td><div class='message'>Thank you for your business!</div></td><td>")
                .append("<table class='totals-table'>")
                .append("<tr><td>SUBTOTAL</td><td class='amount'>").append(symbol).append(formatMoney(receipt.getSubtotal(), currency)).append("</td></tr>");
        if (receipt.getDiscountAmount() != null && receipt.getDiscountAmount().compareTo(BigDecimal.ZERO) > 0) {
            html.append("<tr><td>DISCOUNT</td><td class='amount'>-")
                    .append(symbol).append(formatMoney(receipt.getDiscountAmount(), currency)).append("</td></tr>");
        }
        if (receipt.getTaxAmount() != null && receipt.getTaxAmount().compareTo(BigDecimal.ZERO) > 0) {
            html.append("<tr><td>TAX</td><td class='amount'>")
                    .append(symbol).append(formatMoney(receipt.getTaxAmount(), currency)).append("</td></tr>");
        }
        if (receipt.getDeliveryCharge() != null && receipt.getDeliveryCharge().compareTo(BigDecimal.ZERO) > 0) {
            html.append("<tr><td>SHIPPING</td><td class='amount'>")
                    .append(symbol).append(formatMoney(receipt.getDeliveryCharge(), currency)).append("</td></tr>");
        }
        if (receipt.getOtherCharge() != null && receipt.getOtherCharge().compareTo(BigDecimal.ZERO) > 0) {
            html.append("<tr><td>EXTRA CHARGE</td><td class='amount'>")
                    .append(symbol).append(formatMoney(receipt.getOtherCharge(), currency)).append("</td></tr>");
        }
        html.append("<tr><td>TOTAL</td><td class='amount'>").append(symbol).append(formatMoney(total, currency)).append("</td></tr>")
                .append("<tr><td>").append(saleReceipt ? "AMOUNT PAID" : "PAYMENT RECEIVED").append("</td><td class='amount'>").append(symbol).append(formatMoney(paid, currency)).append("</td></tr>");
        if (receipt.getOldBalance() != null && receipt.getOldBalance().compareTo(BigDecimal.ZERO) > 0) {
            html.append("<tr><td>OLD BALANCE</td><td class='amount'>")
                    .append(symbol).append(formatMoney(receipt.getOldBalance(), currency)).append("</td></tr>");
        }
        if (receipt.getTotalBalance() != null && receipt.getTotalBalance().compareTo(BigDecimal.ZERO) > 0) {
            html.append("<tr><td>TOTAL BALANCE</td><td class='amount'>")
                    .append(symbol).append(formatMoney(receipt.getTotalBalance(), currency)).append("</td></tr>");
        }
        html.append("<tr><td class='balance-label'>BALANCE DUE</td><td class='balance-amount amount'>").append(symbol).append(formatMoney(balance, currency)).append("</td></tr>")
                .append("</table></td></tr></table>");
        appendStandardPaymentSummary(html, receipt, symbol, currency, saleReceipt, invoiceDate);
        if (receipt.getTaxAmount() != null && receipt.getTaxAmount().compareTo(BigDecimal.ZERO) > 0) {
            html.append("<section class='tax-summary'><div class='tax-title'>Tax summary</div>")
                    .append("<div class='tax-head'><span>Rate</span><span>VAT</span><span>Net</span></div>")
                    .append("<div class='tax-row'><span>Tax</span><span>").append(symbol).append(formatMoney(receipt.getTaxAmount(), currency))
                    .append("</span><span>").append(symbol).append(formatMoney(receipt.getSubtotal(), currency)).append("</span></div></section>");
        }
        if (receipt.getFooter() != null && !receipt.getFooter().isBlank()) {
            html.append("<div class='message'>").append(escapeHtml(receipt.getFooter())).append("</div>");
        }
        if (qrImage != null) {
            html.append("<div class='qr'>")
                    .append("<img src='").append(qrImage).append("' />")
                    .append("<div>Scan to view ").append(saleReceipt ? "sale receipt" : "invoice").append("</div>")
                    .append("</div>");
        }
        html.append("<footer class='page-footer'>Page 1 of 1</footer>")
                .append("</main></body></html>");
        return html.toString();
    }

    private String generateThermalReceiptHtml(com.kaknnea.pos.dto.ReceiptDtos.ReceiptResponse receipt) {
        String qrImage = buildQrImageData(receipt.getSaleId(), 120);
        String currency = receipt.getCurrency();
        String symbol = currencySymbol(currency);
        StringBuilder html = new StringBuilder();
        html.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/><style>")
                .append("@page { size: 80mm auto; margin: 0; }")
                .append("body { font-family: 'Noto Sans Khmer','KhmerFallback',sans-serif; font-size: 10px; line-height: 1.45; width: 80mm; margin: 0 auto; padding: 5mm; color: #000; }")
                .append(".center { text-align: center; }")
                .append(".bold { font-weight: bold; }")
                .append(".line { border-top: 1px dashed #000; margin: 3px 0; }")
                .append(".row { display: flex; justify-content: space-between; margin: 2px 0; }")
                .append(".total { font-size: 12px; font-weight: bold; }")
                .append("table { width: 100%; border-collapse: collapse; }")
                .append("th, td { padding: 2px 0; text-align: left; font-size: 10px; }")
                .append("th { font-weight: bold; }")
                .append("td.num, th.num { text-align: right; }")
                .append(".modifiers { display: block; font-size: 9px; font-style: italic; color: #444; }")
                .append("</style></head><body>");

        // Header
        html.append("<div class='center bold'>")
                .append(nullToEmpty(receipt.getBusinessName())).append("<br/>")
                .append(nullToEmpty(receipt.getAddress())).append("<br/>")
                .append(nullToEmpty(receipt.getPhone())).append("<br/>")
                .append("</div>")
                .append("<div class='line'></div>");

        // Invoice info
        String dateTime = "";
        if (receipt.getCreatedAt() != null) {
            try {
                java.time.Instant instant = java.time.Instant.parse(receipt.getCreatedAt());
                dateTime = java.time.ZonedDateTime.ofInstant(instant, java.time.ZoneId.systemDefault())
                        .format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"));
            } catch (java.time.format.DateTimeParseException ex) {
                try {
                    dateTime = java.time.LocalDateTime.parse(receipt.getCreatedAt())
                            .format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"));
                } catch (java.time.format.DateTimeParseException ignored) {
                    dateTime = receipt.getCreatedAt();
                }
            }
        }
        html.append("<div class='center'>")
                .append("វិក្កយបត្រលេខ / Invoice #").append(receipt.getSaleId()).append("<br/>")
                .append(dateTime)
                .append("</div>")
                .append("<div class='line'></div>");
        if (receipt.getCashierName() != null || receipt.getShiftId() != null || receipt.getStoreName() != null) {
            html.append("<div class='center'>")
                    .append(nullToEmpty(receipt.getCashierName()))
                    .append(receipt.getShiftId() != null ? " • Shift #" + receipt.getShiftId() : "")
                    .append(receipt.getStoreName() != null ? " • " + receipt.getStoreName() : "")
                    .append("</div><div class='line'></div>");
        }
        if (receipt.getTableNumber() != null && !receipt.getTableNumber().isBlank()) {
            html.append("<div class='center bold'>Table: ")
                    .append(escapeHtml(receipt.getTableNumber()))
                    .append("</div><div class='line'></div>");
        }

        // Items
        html.append("<table><thead><tr>")
                .append("<th>Item</th>")
                .append("<th class='num'>Qty</th>")
                .append("<th class='num'>Price</th>")
                .append("<th class='num'>Total</th>")
                .append("</tr></thead><tbody>");
        if (receipt.getLines() != null) {
            for (var line : receipt.getLines()) {
                String itemName = buildItemName(line.getNameKm(), line.getNameEn());
                html.append("<tr>")
                        .append("<td>").append(itemName);
                BigDecimal modifierAmount = line.getModifierAmount() == null ? BigDecimal.ZERO : line.getModifierAmount();
                if (modifierAmount.compareTo(BigDecimal.ZERO) != 0) {
                    BigDecimal basePrice = (line.getUnitPrice() == null ? BigDecimal.ZERO : line.getUnitPrice())
                            .subtract(modifierAmount);
                    html.append("<span class='modifiers'>Base: ").append(symbol).append(formatMoney(basePrice, currency))
                            .append(" + Modifier: ").append(symbol).append(formatMoney(modifierAmount, currency))
                            .append("</span>");
                }
                if (line.getModifierSummary() != null && !line.getModifierSummary().isBlank()) {
                    html.append("<span class='modifiers'>").append(escapeHtml(line.getModifierSummary())).append("</span>");
                }
                html.append("</td>")
                        .append("<td class='num'>").append(line.getQty()).append("</td>")
                        .append("<td class='num'>").append(formatMoney(line.getUnitPrice(), currency)).append("</td>")
                        .append("<td class='num'>").append(formatMoney(line.getLineTotal(), currency)).append("</td>")
                        .append("</tr>");
            }
        }
        html.append("</tbody></table>");

        html.append("<div class='line'></div>");

        // Totals
        html.append("<div class='row'>")
                .append("  <span>សរុបរង / Subtotal:</span>")
                .append("  <span>").append(symbol).append(formatMoney(receipt.getSubtotal(), currency))
                .append("</span>")
                .append("</div>");

        if (receipt.getDiscountAmount() != null
                && receipt.getDiscountAmount().compareTo(java.math.BigDecimal.ZERO) > 0) {
            html.append("<div class='row'>")
                    .append("  <span>បញ្ចុះតម្លៃ / Discount:</span>")
                    .append("  <span>-").append(symbol).append(formatMoney(receipt.getDiscountAmount(), currency))
                    .append("</span>")
                    .append("</div>");
        }

        if (receipt.getTaxAmount() != null && receipt.getTaxAmount().compareTo(java.math.BigDecimal.ZERO) > 0) {
            html.append("<div class='row'>")
                    .append("  <span>ពន្ធ / Tax:</span>")
                    .append("  <span>").append(symbol).append(formatMoney(receipt.getTaxAmount(), currency))
                    .append("</span>")
                    .append("</div>");
        }

        html.append("<div class='line'></div>");
        html.append("<div class='row total'>")
                .append("  <span>សរុប / TOTAL:</span>")
                .append("  <span>").append(symbol).append(formatMoney(receipt.getTotal(), currency)).append("</span>")
                .append("</div>");

        appendPaymentSummary(html, receipt, symbol, currency);

        // Footer
        String footer = receipt.getFooter();
        if (footer != null && !footer.isEmpty()) {
            html.append("<div class='line'></div>")
                    .append("<div class='center'>").append(footer).append("</div>");
        }

        if (qrImage != null) {
            html.append("<div class='line'></div>")
                    .append("<div class='center'>")
                    .append("<img src='").append(qrImage).append("' width='120' height='120' />")
                    .append("<div>Scan to view invoice</div>")
                    .append("</div>");
        }

        html.append("<div class='center' style='margin-top: 5mm;'>")
                .append("អរគុណ! / Thank You!")
                .append("</div>");

        html.append("</body></html>");
        return html.toString();
    }

    private void appendPaymentSummary(StringBuilder html,
            com.kaknnea.pos.dto.ReceiptDtos.ReceiptResponse receipt,
            String symbol,
            String currency) {
        BigDecimal total = receipt.getTotal() == null ? BigDecimal.ZERO : receipt.getTotal();
        BigDecimal paid = receipt.getPaidAmount() == null ? BigDecimal.ZERO : receipt.getPaidAmount();
        BigDecimal balance = total.subtract(paid);
        BigDecimal change = receipt.getChangeAmount() == null ? paid.subtract(total) : receipt.getChangeAmount();

        html.append("<div style='margin-top:6px;'>")
                .append("<div>Paid: ").append(symbol).append(formatMoney(paid, currency)).append("</div>");
        if (receipt.getPayments() != null && !receipt.getPayments().isEmpty()) {
            html.append("<div>Payments:</div>");
            for (var payment : receipt.getPayments()) {
                html.append("<div>")
                        .append(payment.getMethod())
                        .append(": ")
                        .append(payment.getAmount().compareTo(BigDecimal.ZERO) < 0 ? "-" : "")
                        .append(symbol)
                        .append(formatMoney(payment.getAmount().abs(), currency))
                        .append("</div>");
            }
        }
        if (receipt.getRefundedAmount() != null && receipt.getRefundedAmount().compareTo(BigDecimal.ZERO) > 0) {
            html.append("<div>Refunded: ").append(symbol).append(formatMoney(receipt.getRefundedAmount(), currency)).append("</div>");
        }
        if (receipt.getOldBalance() != null) {
            html.append("<div>Old Balance: ").append(symbol).append(formatMoney(receipt.getOldBalance(), currency)).append("</div>");
        }
        if (receipt.getTotalBalance() != null) {
            html.append("<div>Total Balance: ").append(symbol).append(formatMoney(receipt.getTotalBalance(), currency)).append("</div>");
        }

        if (balance.compareTo(BigDecimal.ZERO) > 0) {
            html.append("<div>Balance: ").append(symbol).append(formatMoney(balance, currency)).append("</div>");
        }
        if (change.compareTo(BigDecimal.ZERO) > 0) {
            html.append("<div>Change: ").append(symbol).append(formatMoney(change, currency)).append("</div>");
        }
        if (receipt.getStatus() != null) {
            html.append("<div>Status: ").append(receipt.getStatus()).append("</div>");
        }
        html.append("</div>");
    }

    private void appendStandardPaymentSummary(StringBuilder html,
            com.kaknnea.pos.dto.ReceiptDtos.ReceiptResponse receipt,
            String symbol,
            String currency,
            boolean saleReceipt,
            String invoiceDate) {
        BigDecimal paid = receipt.getPaidAmount() == null ? BigDecimal.ZERO : receipt.getPaidAmount();
        boolean hasPayments = receipt.getPayments() != null && !receipt.getPayments().isEmpty();
        if (paid.compareTo(BigDecimal.ZERO) <= 0 && !hasPayments) {
            return;
        }

        html.append("<section class='payment-summary'>")
                .append("<div class='section-title'>")
                .append(saleReceipt ? "Payment receipt" : "Payments applied")
                .append("</div>")
                .append("<table class='payment-grid'><tr>")
                .append("<td><span>Payment status</span><strong>")
                .append(escapeHtml(nullToEmpty(receipt.getStatus())))
                .append("</strong></td>")
                .append("<td><span>Payment date</span><strong>")
                .append(escapeHtml(invoiceDate))
                .append("</strong></td>")
                .append("<td><span>Total paid</span><strong>")
                .append(symbol).append(formatMoney(paid, currency))
                .append("</strong></td>")
                .append("</tr></table>");

        if (hasPayments) {
            html.append("<table class='payments-table'><thead><tr>")
                    .append("<th>METHOD</th><th class='num'>AMOUNT</th>")
                    .append("</tr></thead><tbody>");
            for (var payment : receipt.getPayments()) {
                BigDecimal amount = payment.getAmount() == null ? BigDecimal.ZERO : payment.getAmount();
                html.append("<tr><td>")
                        .append(escapeHtml(nullToEmpty(payment.getMethod())))
                        .append("</td><td class='num'>")
                        .append(amount.compareTo(BigDecimal.ZERO) < 0 ? "-" : "")
                        .append(symbol)
                        .append(formatMoney(amount.abs(), currency))
                        .append("</td></tr>");
            }
            html.append("</tbody></table>");
        }

        html.append("</section>");
    }

    private String buildItemName(String nameKm, String nameEn) {
        String km = cleanDisplayText(nameKm).trim();
        String en = cleanDisplayText(nameEn).trim();
        if (!km.isEmpty() && !en.isEmpty() && !km.equalsIgnoreCase(en)) {
            return km + " (" + en + ")";
        }
        return !km.isEmpty() ? km : en;
    }

    private String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    private String cleanDisplayText(String value) {
        if (value == null) {
            return "";
        }
        return Normalizer.normalize(value, Normalizer.Form.NFC)
                .replace("\u200B", "")
                .replace("\u200C", "")
                .replace("\u200D", "")
                .replace("\uFEFF", "");
    }

    private String formatInvoiceDate(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        try {
            java.time.Instant instant = java.time.Instant.parse(value);
            return java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy")
                    .withZone(java.time.ZoneId.systemDefault())
                    .format(instant);
        } catch (Exception ignored) {
            try {
                return java.time.LocalDateTime.parse(value)
                        .format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));
            } catch (Exception ignoredAgain) {
                return value.length() >= 10 ? value.substring(0, 10) : value;
            }
        }
    }

    private String currencySymbol(String currency) {
        if (currency == null) {
            return "";
        }
        String code = currency.trim().toUpperCase(java.util.Locale.US);
        if ("KHR".equals(code)) {
            return "៛";
        }
        if ("USD".equals(code)) {
            return "$";
        }
        return code + " ";
    }

    private String formatMoney(BigDecimal amount, String currency) {
        BigDecimal safe = amount == null ? BigDecimal.ZERO : amount;
        if (currency != null && "KHR".equalsIgnoreCase(currency)) {
            return String.format(java.util.Locale.US, "%,.0f", safe);
        }
        return String.format(java.util.Locale.US, "%,.2f", safe);
    }

    private String buildQrImageData(Long saleId, int size) {
        String baseUrl = System.getenv("QR_BASE_URL");
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "http://localhost:4200";
        }
        if (baseUrl.endsWith("/")) {
            baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
        }
        String data = baseUrl + "/invoice/" + saleId;
        try {
            com.google.zxing.common.BitMatrix matrix = new com.google.zxing.qrcode.QRCodeWriter()
                    .encode(data, com.google.zxing.BarcodeFormat.QR_CODE, size, size);
            java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
            com.google.zxing.client.j2se.MatrixToImageWriter.writeToStream(matrix, "PNG", out);
            return "data:image/png;base64," + java.util.Base64.getEncoder().encodeToString(out.toByteArray());
        } catch (Exception e) {
            return null;
        }
    }

}
