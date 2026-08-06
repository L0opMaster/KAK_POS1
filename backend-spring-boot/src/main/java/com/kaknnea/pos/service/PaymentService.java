package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.dto.CreditCollectionDtos;
import com.kaknnea.pos.dto.PaymentDtos;
import com.kaknnea.pos.repository.*;
import com.kaknnea.pos.util.DocumentNumberUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@Transactional
public class PaymentService {

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private TransactionRepository transactionRepository;

    @Autowired
    private CartRepository cartRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private StoreRepository storeRepository;

    @Autowired
    private CustomerCreditAccountRepository creditAccountRepository;

    @Autowired
    private CreditCollectionService creditCollectionService;

    @Autowired
    private CustomerCreditAllocationRepository allocationRepository;

    @Autowired
    private CustomerCreditOpeningBalanceRepository openingBalanceRepository;

    @Autowired
    private SaleRepository saleRepository;

    // Create payment from cart
    public PaymentDtos.PaymentResponse createPayment(PaymentDtos.CreatePaymentRequest request) {
        request.validate();

        Cart cart = cartRepository.findById(request.getCartId())
                .orElseThrow(() -> new RuntimeException("Cart not found with ID: " + request.getCartId()));

        if (!cart.isActive()) {
            throw new RuntimeException("Cannot create payment for inactive cart");
        }

        if (cart.getItems().isEmpty()) {
            throw new RuntimeException("Cannot create payment for empty cart");
        }

        // Create new payment
        Payment.PaymentMethod paymentMethod = Payment.PaymentMethod.valueOf(request.getPaymentMethod().trim().toUpperCase());
        Payment payment = Payment.builder()
                .cart(cart)
                .customer(cart.getCustomer())
                .store(cart.getStore())
                .amount(cart.getTotalAmount())
                .currency("USD")
                .status(Payment.PaymentStatus.PENDING)
                .paymentMethod(paymentMethod)
                .method(paymentMethod == Payment.PaymentMethod.CASH ? "CASH" : paymentMethod.name())
                .referenceNumber(generateReferenceNumber())
                .notes(request.getNotes())
                .build();

        Payment savedPayment = paymentRepository.save(payment);
        savedPayment.setReferenceNumber(DocumentNumberUtil.paymentReference(savedPayment));
        savedPayment = paymentRepository.save(savedPayment);
        log.info("Created payment with ID: {} for cart: {}", savedPayment.getId(), cart.getId());

        return mapPaymentToResponse(savedPayment);
    }

    // Get payment by ID
    public PaymentDtos.PaymentResponse getPayment(Long paymentId) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new RuntimeException("Payment not found with ID: " + paymentId));

        return mapPaymentToResponse(payment);
    }

    @Transactional
    public PaymentDtos.PaymentResponse updatePayment(Long paymentId, PaymentDtos.UpdatePaymentRequest request) {
        request.validate();
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new RuntimeException("Payment not found with ID: " + paymentId));

        Customer affectedCustomer = resolvePaymentCustomer(payment);
        List<CustomerCreditAllocation> oldAllocations = allocationRepository.findByPaymentIdOrderByCreatedAtAsc(paymentId);
        reversePaymentEffects(payment, oldAllocations);

        BigDecimal nextAmount = scale(request.getAmount());
        Payment.PaymentMethod method = Payment.PaymentMethod.valueOf(request.getPaymentMethod().trim().toUpperCase());
        payment.setAmount(nextAmount);
        payment.setPaymentMethod(method);
        payment.setMethod(method.name());
        payment.setNotes(request.getNotes());
        payment.setStatus(nextAmount.compareTo(BigDecimal.ZERO) > 0
                ? Payment.PaymentStatus.COMPLETED
                : Payment.PaymentStatus.VOID);
        payment = paymentRepository.save(payment);

        if (nextAmount.compareTo(BigDecimal.ZERO) > 0) {
            applyPaymentEffects(payment, oldAllocations, nextAmount);
        }
        transactionRepository.save(Transaction.builder()
                .payment(payment)
                .transactionType(Transaction.TransactionType.SETTLEMENT)
                .amount(nextAmount)
                .status(Transaction.TransactionStatus.SUCCESS)
                .processorName("Manual")
                .notes("Payment edited" + (request.getReason() == null || request.getReason().isBlank() ? "" : ": " + request.getReason()))
                .build());

        syncCustomer(affectedCustomer);
        return mapPaymentToResponse(payment);
    }

    @Transactional
    public PaymentDtos.PaymentResponse deletePayment(Long paymentId, String reason) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new RuntimeException("Payment not found with ID: " + paymentId));
        Customer affectedCustomer = resolvePaymentCustomer(payment);
        List<CustomerCreditAllocation> oldAllocations = allocationRepository.findByPaymentIdOrderByCreatedAtAsc(paymentId);
        reversePaymentEffects(payment, oldAllocations);

        String resolvedReason = reason == null || reason.isBlank() ? "Deleted by user" : reason.trim();
        payment.setAmount(BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP));
        payment.setStatus(Payment.PaymentStatus.VOID);
        payment.setNotes(resolvedReason);
        payment = paymentRepository.save(payment);
        transactionRepository.save(Transaction.builder()
                .payment(payment)
                .transactionType(Transaction.TransactionType.VOID)
                .amount(BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP))
                .status(Transaction.TransactionStatus.SUCCESS)
                .processorName("Manual")
                .notes(resolvedReason)
                .build());

        syncCustomer(affectedCustomer);
        return mapPaymentToResponse(payment);
    }

    // Get payment by cart
    public PaymentDtos.PaymentResponse getPaymentByCart(Long cartId) {
        Payment payment = paymentRepository.findByCartId(cartId)
                .orElseThrow(() -> new RuntimeException("Payment not found for cart ID: " + cartId));

        return mapPaymentToResponse(payment);
    }

    // Get payment status
    public PaymentDtos.PaymentStatusResponse getPaymentStatus(Long paymentId) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new RuntimeException("Payment not found with ID: " + paymentId));

        return PaymentDtos.PaymentStatusResponse.builder()
                .paymentId(payment.getId())
                .status(payment.getStatus().name())
                .statusDisplay(payment.getStatus().getDisplayName())
                .isCompleted(payment.isCompleted())
                .isFailed(payment.isFailed())
                .errorMessage(payment.getErrorMessage())
                .failureReason(payment.getFailureReason())
                .transactions(mapTransactionsToResponses(payment.getTransactions()))
                .updatedAt(payment.getUpdatedAt())
                .build();
    }

    // Process payment
    @Transactional
    public PaymentDtos.PaymentResponse processPayment(PaymentDtos.ProcessPaymentRequest request) {
        request.validate();

        Payment payment = paymentRepository.findById(request.getPaymentId())
                .orElseThrow(() -> new RuntimeException("Payment not found with ID: " + request.getPaymentId()));

        if (!payment.isPending()) {
            throw new RuntimeException("Payment is not in pending status: " + payment.getStatus());
        }

        payment.markAsProcessing();

        try {
            // Create authorization transaction
            Transaction authTransaction = Transaction.builder()
                    .payment(payment)
                    .transactionType(Transaction.TransactionType.AUTHORIZATION)
                    .amount(payment.getAmount())
                    .status(Transaction.TransactionStatus.PENDING)
                    .processorName("Payment Gateway")
                    .notes(request.getNotes())
                    .build();

            authTransaction = transactionRepository.save(authTransaction);

            // Simulate gateway processing (replace with real gateway integration)
            authTransaction.setGatewayTransactionId(generateTransactionId());
            authTransaction.setAuthCode(generateAuthCode());
            authTransaction.setLastFourDigits(maskCardNumber(request.getCardToken()));
            authTransaction.setCardBrand("Visa");
            authTransaction.markAsSuccess();

            transactionRepository.save(authTransaction);

            // Create capture transaction
            Transaction captureTransaction = Transaction.builder()
                    .payment(payment)
                    .transactionType(Transaction.TransactionType.CAPTURE)
                    .amount(payment.getAmount())
                    .status(Transaction.TransactionStatus.SUCCESS)
                    .gatewayTransactionId(authTransaction.getGatewayTransactionId())
                    .processorName("Payment Gateway")
                    .build();

            transactionRepository.save(captureTransaction);

            // Mark payment as completed
            payment.markAsCompleted(authTransaction.getGatewayTransactionId());
            paymentRepository.save(payment);

            log.info("Successfully processed payment ID: {}", payment.getId());
            return mapPaymentToResponse(payment);

        } catch (Exception e) {
            payment.markAsFailed(e.getMessage());
            paymentRepository.save(payment);
            log.error("Failed to process payment ID: {}", payment.getId(), e);
            throw new RuntimeException("Payment processing failed: " + e.getMessage());
        }
    }

    // Refund payment
    @Transactional
    public PaymentDtos.PaymentResponse refundPayment(PaymentDtos.RefundPaymentRequest request) {
        request.validate();

        Payment payment = paymentRepository.findById(request.getPaymentId())
                .orElseThrow(() -> new RuntimeException("Payment not found with ID: " + request.getPaymentId()));

        if (!payment.isRefundable()) {
            throw new RuntimeException("Payment cannot be refunded in status: " + payment.getStatus());
        }

        try {
            // Create refund transaction
            Transaction refundTransaction = Transaction.builder()
                    .payment(payment)
                    .transactionType(Transaction.TransactionType.REFUND)
                    .amount(request.getRefundAmount())
                    .status(Transaction.TransactionStatus.SUCCESS)
                    .gatewayTransactionId(generateTransactionId())
                    .processorName("Payment Gateway")
                    .notes(request.getReason())
                    .build();

            transactionRepository.save(refundTransaction);

            // Mark payment as refunded if full refund
            if (request.getRefundAmount().compareTo(payment.getAmount()) >= 0) {
                payment.markAsRefunded();
            }

            paymentRepository.save(payment);
            log.info("Successfully refunded payment ID: {}", payment.getId());

            return mapPaymentToResponse(payment);

        } catch (Exception e) {
            log.error("Failed to refund payment ID: {}", payment.getId(), e);
            throw new RuntimeException("Payment refund failed: " + e.getMessage());
        }
    }

    // Get customer payments
    public PaymentDtos.PaymentListResponse getCustomerPayments(Long customerId) {
        creditCollectionService.synchronizeCustomerState(customerId);
        List<Payment> payments = paymentRepository.findByCustomerOrSaleCustomerId(customerId).stream()
                .sorted((a, b) -> {
                    LocalDateTime aTime = a.getCreatedAt();
                    LocalDateTime bTime = b.getCreatedAt();
                    if (aTime == null && bTime == null) {
                        return Long.compare(
                                b.getId() == null ? 0L : b.getId(),
                                a.getId() == null ? 0L : a.getId());
                    }
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    int byTime = bTime.compareTo(aTime);
                    if (byTime != 0) return byTime;
                    return Long.compare(
                            b.getId() == null ? 0L : b.getId(),
                            a.getId() == null ? 0L : a.getId());
                })
                .collect(Collectors.toList());

        return PaymentDtos.PaymentListResponse.builder()
                .payments(payments.stream().map(this::mapPaymentToResponse).collect(Collectors.toList()))
                .totalCount(payments.size())
                .pageNumber(1)
                .pageSize(payments.size())
                .build();
    }

    // Get payments by status
    public PaymentDtos.PaymentListResponse getPaymentsByStatus(Payment.PaymentStatus status) {
        List<Payment> payments = paymentRepository.findByStatus(status);

        return PaymentDtos.PaymentListResponse.builder()
                .payments(payments.stream().map(this::mapPaymentToResponse).collect(Collectors.toList()))
                .totalCount(payments.size())
                .pageNumber(1)
                .pageSize(payments.size())
                .build();
    }

    public PaymentDtos.PaymentListResponse getPayments(LocalDateTime from, LocalDateTime to) {
        List<Payment> payments = (from != null && to != null)
                ? paymentRepository.findByCreatedAtBetweenOrderByCreatedAtDescIdDesc(from, to)
                : paymentRepository.findAllByOrderByCreatedAtDescIdDesc();

        return PaymentDtos.PaymentListResponse.builder()
                .payments(payments.stream().map(this::mapPaymentToResponse).collect(Collectors.toList()))
                .totalCount(payments.size())
                .pageNumber(1)
                .pageSize(payments.size())
                .build();
    }

    // Get payment statistics
    public PaymentDtos.PaymentListResponse getDailyPayments() {
        LocalDateTime startOfDay = LocalDateTime.now().withHour(0).withMinute(0).withSecond(0);
        LocalDateTime endOfDay = LocalDateTime.now().withHour(23).withMinute(59).withSecond(59);

        List<Payment> payments = paymentRepository.findByStatusAndDateRange(
                Payment.PaymentStatus.COMPLETED,
                startOfDay,
                endOfDay);

        return PaymentDtos.PaymentListResponse.builder()
                .payments(payments.stream().map(this::mapPaymentToResponse).collect(Collectors.toList()))
                .totalCount(payments.size())
                .pageNumber(1)
                .pageSize(payments.size())
                .build();
    }

    // Helper methods
    public PaymentDtos.PaymentResponse recordCustomerRepayment(Long customerId,
            com.kaknnea.pos.dto.CustomerDtos.CustomerRepaymentRequest request) {
        if (request.getAmount() == null || request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("Repayment amount must be greater than zero");
        }
        if (request.getPaymentMethod() == null || request.getPaymentMethod().isBlank()) {
            throw new RuntimeException("Payment method is required");
        }
        CreditCollectionDtos.CollectRequest collectRequest = new CreditCollectionDtos.CollectRequest();
        collectRequest.setAmount(request.getAmount());
        collectRequest.setPaymentMethod(request.getPaymentMethod());
        collectRequest.setNotes(request.getNotes());
        collectRequest.setStrategy("FIFO");
        collectRequest.setIdempotencyKey(generateReferenceNumber());
        collectRequest.setAllocations(request.getAllocations());

        CreditCollectionDtos.CollectResponse response = creditCollectionService.collect(customerId, collectRequest);
        Payment payment = paymentRepository.findById(response.getPaymentId())
                .orElseThrow(() -> new RuntimeException("Repayment payment not found: " + response.getPaymentId()));
        return mapPaymentToResponse(payment);
    }

    private PaymentDtos.PaymentResponse mapPaymentToResponse(Payment payment) {
        Long cartId = payment.getCart() != null ? payment.getCart().getId() : null;
        Long saleId = payment.getSale() != null ? payment.getSale().getId() : null;
        String saleDocumentNumber = payment.getSale() == null
                ? null
                : (isSaleReceiptPayment(payment)
                        ? DocumentNumberUtil.saleReceiptNumber(payment.getSale())
                        : DocumentNumberUtil.saleNumber(payment.getSale()));
        Long customerId = payment.getCustomer() != null
                ? payment.getCustomer().getId()
                : (payment.getSale() != null && payment.getSale().getCustomer() != null
                        ? payment.getSale().getCustomer().getId()
                        : null);
        Long storeId = payment.getStore() != null ? payment.getStore().getId() : null;
        return PaymentDtos.PaymentResponse.builder()
                .id(payment.getId())
                .cartId(cartId)
                .saleId(saleId)
                .saleDocumentNumber(saleDocumentNumber)
                .customerId(customerId)
                .storeId(storeId)
                .amount(payment.getAmount())
                .currency(payment.getCurrency())
                .status(payment.getStatus().name())
                .paymentMethod(payment.getPaymentMethod() != null ? payment.getPaymentMethod().getDisplayName() : null)
                .transactionId(payment.getTransactionId())
                .referenceNumber(DocumentNumberUtil.paymentReference(payment))
                .errorMessage(payment.getErrorMessage())
                .failureReason(payment.getFailureReason())
                .notes(payment.getNotes())
                .createdAt(payment.getCreatedAt())
                .updatedAt(payment.getUpdatedAt())
                .createdBy(payment.getCreatedBy())
                .transactions(mapTransactionsToResponses(payment.getTransactions()))
                .build();
    }

    private boolean isSaleReceiptPayment(Payment payment) {
        if (payment == null || payment.getSale() == null) {
            return false;
        }
        var sale = payment.getSale();
        String terms = sale.getPaymentTerms() == null ? "" : sale.getPaymentTerms().trim().toUpperCase();
        String status = sale.getStatus() == null ? "" : sale.getStatus().trim().toUpperCase();
        boolean receiptSource = sale.getShift() != null || "CASH".equals(terms);
        return receiptSource && !"CREDIT".equals(status) && !"DRAFT".equals(status) && !"HOLD".equals(status);
    }

    private List<PaymentDtos.TransactionResponse> mapTransactionsToResponses(List<Transaction> transactions) {
        if (transactions == null || transactions.isEmpty()) {
            return List.of();
        }

        return transactions.stream()
                .map(t -> PaymentDtos.TransactionResponse.builder()
                        .id(t.getId())
                        .paymentId(t.getPayment().getId())
                        .transactionType(t.getTransactionType().name())
                        .amount(t.getAmount())
                        .status(t.getStatus().name())
                        .gatewayTransactionId(t.getGatewayTransactionId())
                        .gatewayResponseCode(t.getGatewayResponseCode())
                        .gatewayResponseMessage(t.getGatewayResponseMessage())
                        .processorName(t.getProcessorName())
                        .lastFourDigits(t.getLastFourDigits())
                        .cardBrand(t.getCardBrand())
                        .authCode(t.getAuthCode())
                        .notes(t.getNotes())
                        .transactionDate(t.getTransactionDate())
                        .createdAt(t.getCreatedAt())
                        .createdBy(t.getCreatedBy())
                        .build())
                .collect(Collectors.toList());
    }

    private void reversePaymentEffects(Payment payment, List<CustomerCreditAllocation> allocations) {
        BigDecimal paymentAmount = scale(payment.getAmount() == null ? BigDecimal.ZERO : payment.getAmount());
        if (allocations != null && !allocations.isEmpty()) {
            for (CustomerCreditAllocation allocation : allocations) {
                BigDecimal amount = scale(allocation.getAmount());
                if (allocation.getSale() != null) {
                    Sale sale = allocation.getSale();
                    sale.setPaidAmount(scale(safe(sale.getPaidAmount()).subtract(amount)));
                    if (sale.getPaidAmount().compareTo(BigDecimal.ZERO) < 0) {
                        sale.setPaidAmount(BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP));
                    }
                    refreshSalePaymentStatus(sale);
                    saleRepository.save(sale);
                }
                if (allocation.getOpeningBalance() != null) {
                    CustomerCreditOpeningBalance opening = allocation.getOpeningBalance();
                    opening.setRemainingAmount(scale(safe(opening.getRemainingAmount()).add(amount)));
                    openingBalanceRepository.save(opening);
                }
            }
            allocationRepository.deleteAll(allocations);
            return;
        }

        if (payment.getSale() != null && paymentAmount.compareTo(BigDecimal.ZERO) > 0) {
            Sale sale = payment.getSale();
            sale.setPaidAmount(scale(safe(sale.getPaidAmount()).subtract(paymentAmount)));
            if (sale.getPaidAmount().compareTo(BigDecimal.ZERO) < 0) {
                sale.setPaidAmount(BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP));
            }
            refreshSalePaymentStatus(sale);
            saleRepository.save(sale);
        }
    }

    private void applyPaymentEffects(Payment payment, List<CustomerCreditAllocation> oldAllocations, BigDecimal amount) {
        BigDecimal remaining = scale(amount);
        if (oldAllocations != null && !oldAllocations.isEmpty()) {
            for (CustomerCreditAllocation old : oldAllocations) {
                if (remaining.compareTo(BigDecimal.ZERO) <= 0) {
                    break;
                }
                if (old.getSale() != null) {
                    Sale sale = saleRepository.findById(old.getSale().getId())
                            .orElseThrow(() -> new RuntimeException("Sale target not found"));
                    BigDecimal outstanding = scale(safe(sale.getGrandTotal()).subtract(safe(sale.getPaidAmount())));
                    BigDecimal applied = remaining.min(outstanding.max(BigDecimal.ZERO));
                    if (applied.compareTo(BigDecimal.ZERO) > 0) {
                        sale.setPaidAmount(scale(safe(sale.getPaidAmount()).add(applied)));
                        refreshSalePaymentStatus(sale);
                        saleRepository.save(sale);
                        createAllocation(payment, resolvePaymentCustomer(payment), sale, null, applied, payment.getNotes());
                        remaining = scale(remaining.subtract(applied));
                    }
                } else if (old.getOpeningBalance() != null) {
                    CustomerCreditOpeningBalance opening = openingBalanceRepository.findById(old.getOpeningBalance().getId())
                            .orElseThrow(() -> new RuntimeException("Opening balance target not found"));
                    BigDecimal outstanding = scale(safe(opening.getRemainingAmount()));
                    BigDecimal applied = remaining.min(outstanding.max(BigDecimal.ZERO));
                    if (applied.compareTo(BigDecimal.ZERO) > 0) {
                        opening.setRemainingAmount(scale(safe(opening.getRemainingAmount()).subtract(applied)));
                        openingBalanceRepository.save(opening);
                        createAllocation(payment, resolvePaymentCustomer(payment), null, opening, applied, payment.getNotes());
                        remaining = scale(remaining.subtract(applied));
                    }
                }
            }
        }

        if (remaining.compareTo(BigDecimal.ZERO) > 0 && payment.getSale() != null) {
            Sale sale = payment.getSale();
            sale.setPaidAmount(scale(safe(sale.getPaidAmount()).add(remaining)));
            refreshSalePaymentStatus(sale);
            saleRepository.save(sale);
            if (sale.getCustomer() != null) {
                createAllocation(payment, sale.getCustomer(), sale, null, remaining, payment.getNotes());
            }
        }
    }

    private void createAllocation(Payment payment, Customer customer, Sale sale,
            CustomerCreditOpeningBalance opening, BigDecimal amount, String notes) {
        if (customer == null || amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }
        CustomerCreditAllocation allocation = new CustomerCreditAllocation();
        allocation.setPayment(payment);
        allocation.setCustomer(customer);
        allocation.setAmount(scale(amount));
        allocation.setNote(notes);
        if (sale != null) {
            allocation.setTargetType(CustomerCreditAllocation.TargetType.SALE);
            allocation.setSale(sale);
        } else {
            allocation.setTargetType(CustomerCreditAllocation.TargetType.OPENING_BALANCE);
            allocation.setOpeningBalance(opening);
        }
        allocationRepository.save(allocation);
    }

    private void refreshSalePaymentStatus(Sale sale) {
        BigDecimal paid = safe(sale.getPaidAmount());
        BigDecimal total = safe(sale.getGrandTotal());
        if (paid.compareTo(total) >= 0 && total.compareTo(BigDecimal.ZERO) > 0) {
            sale.setStatus("PAID");
        } else if (sale.getCreditIssuedAt() != null || !"CASH".equalsIgnoreCase(String.valueOf(sale.getPaymentTerms()))) {
            sale.setStatus("CREDIT");
        }
    }

    private Customer resolvePaymentCustomer(Payment payment) {
        if (payment.getCustomer() != null) {
            return payment.getCustomer();
        }
        if (payment.getSale() != null) {
            return payment.getSale().getCustomer();
        }
        return null;
    }

    private void syncCustomer(Customer customer) {
        if (customer != null && customer.getId() != null) {
            creditCollectionService.syncBalanceForCustomer(customer.getId());
        }
    }

    private BigDecimal safe(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }

    private BigDecimal scale(BigDecimal value) {
        return safe(value).setScale(2, RoundingMode.HALF_UP);
    }

    private String generateReferenceNumber() {
        return "PAY-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }

    private String generateTransactionId() {
        return UUID.randomUUID().toString();
    }

    private String generateAuthCode() {
        return String.format("%06d", (int) (Math.random() * 999999));
    }

    private String maskCardNumber(String cardToken) {
        if (cardToken != null && cardToken.length() >= 4) {
            return cardToken.substring(cardToken.length() - 4);
        }
        return "****";
    }
}
