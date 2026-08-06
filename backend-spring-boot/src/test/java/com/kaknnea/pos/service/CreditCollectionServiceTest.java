package com.kaknnea.pos.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.domain.CustomerCreditOpeningBalance;
import com.kaknnea.pos.domain.Payment;
import com.kaknnea.pos.domain.Sale;
import com.kaknnea.pos.dto.CreditCollectionDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.CustomerAdjustmentRepository;
import com.kaknnea.pos.repository.CustomerCreditAccountRepository;
import com.kaknnea.pos.repository.CustomerCreditAllocationRepository;
import com.kaknnea.pos.repository.CustomerCreditOpeningBalanceRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.PaymentRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.TransactionRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class CreditCollectionServiceTest {

    @Mock
    private CustomerRepository customerRepository;
    @Mock
    private SaleRepository saleRepository;
    @Mock
    private PaymentRepository paymentRepository;
    @Mock
    private TransactionRepository transactionRepository;
    @Mock
    private StoreRepository storeRepository;
    @Mock
    private CustomerCreditOpeningBalanceRepository openingBalanceRepository;
    @Mock
    private CustomerCreditAllocationRepository allocationRepository;
    @Mock
    private CustomerCreditAccountRepository creditAccountRepository;
    @Mock
    private CustomerAdjustmentRepository adjustmentRepository;

    private CreditCollectionService service;

    private Customer customer;

    @BeforeEach
    void setUp() {
        service = new CreditCollectionService();
        ReflectionTestUtils.setField(service, "customerRepository", customerRepository);
        ReflectionTestUtils.setField(service, "saleRepository", saleRepository);
        ReflectionTestUtils.setField(service, "paymentRepository", paymentRepository);
        ReflectionTestUtils.setField(service, "transactionRepository", transactionRepository);
        ReflectionTestUtils.setField(service, "storeRepository", storeRepository);
        ReflectionTestUtils.setField(service, "openingBalanceRepository", openingBalanceRepository);
        ReflectionTestUtils.setField(service, "allocationRepository", allocationRepository);
        ReflectionTestUtils.setField(service, "creditAccountRepository", creditAccountRepository);
        ReflectionTestUtils.setField(service, "adjustmentRepository", adjustmentRepository);

        customer = new Customer();
        customer.setId(1L);
        customer.setCustomerCode("CUST-CREDIT-T01");
        customer.setType("INDIVIDUAL");
        customer.setNameEn("Credit Test");
        customer.setNameKm("");
        customer.setPhone("099123456");
        customer.setCreditLimit(new BigDecimal("500.00"));
        customer.setCreditBalance(new BigDecimal("60.00"));
        lenient().when(customerRepository.findById(1L)).thenReturn(Optional.of(customer));
        lenient().when(customerRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(customer));
        lenient().when(adjustmentRepository.findByCustomerIdOrderByCreatedAtDesc(1L)).thenReturn(List.of());
    }

    @Test
    void previewCollection_allocatesFifo_openingBalanceThenCreditSales() {
        CustomerCreditOpeningBalance opening = new CustomerCreditOpeningBalance();
        opening.setId(11L);
        opening.setCustomer(customer);
        opening.setRemainingAmount(new BigDecimal("10.00"));
        opening.setCreatedAt(Instant.parse("2026-01-01T00:00:00Z"));

        Sale firstDue = new Sale();
        firstDue.setId(21L);
        firstDue.setSaleNumber("INV-21");
        firstDue.setStatus("CREDIT");
        firstDue.setGrandTotal(new BigDecimal("20.00"));
        firstDue.setPaidAmount(BigDecimal.ZERO);
        firstDue.setCreditDueAt(Instant.parse("2026-02-01T00:00:00Z"));
        firstDue.setCreatedAt(Instant.parse("2026-01-15T00:00:00Z"));

        Sale secondDue = new Sale();
        secondDue.setId(22L);
        secondDue.setSaleNumber("INV-22");
        secondDue.setStatus("CREDIT");
        secondDue.setGrandTotal(new BigDecimal("100.00"));
        secondDue.setPaidAmount(BigDecimal.ZERO);
        secondDue.setCreditDueAt(Instant.parse("2026-03-01T00:00:00Z"));
        secondDue.setCreatedAt(Instant.parse("2026-01-20T00:00:00Z"));

        when(openingBalanceRepository.findByCustomerIdAndRemainingAmountGreaterThanOrderByCreatedAtAsc(
                1L, BigDecimal.ZERO))
                .thenReturn(List.of(opening));
        when(saleRepository.findByCustomerIdAndStatusOrderByCreditDueAtAscCreatedAtAsc(1L, "CREDIT"))
                .thenReturn(List.of(firstDue, secondDue));

        CreditCollectionDtos.PreviewResponse preview = service.previewCollection(1L, new BigDecimal("25.00"),
                "FIFO");

        assertTrue(preview.isValid());
        assertEquals(new BigDecimal("25.00"), preview.getAmountAllocatable());
        assertEquals(new BigDecimal("0.00"), preview.getAmountUnallocated());
        assertEquals(2, preview.getAllocations().size());

        CreditCollectionDtos.AllocationRow row1 = preview.getAllocations().get(0);
        assertEquals("OPENING_BALANCE", row1.getTargetType());
        assertEquals(11L, row1.getOpeningBalanceId());
        assertEquals(new BigDecimal("10.00"), row1.getAllocatedAmount());

        CreditCollectionDtos.AllocationRow row2 = preview.getAllocations().get(1);
        assertEquals("SALE", row2.getTargetType());
        assertEquals(21L, row2.getSaleId());
        assertEquals(new BigDecimal("15.00"), row2.getAllocatedAmount());
    }

    @Test
    void collect_withSameIdempotencyKey_returnsExistingPaymentWithoutCreatingNew() {
        Payment existing = Payment.builder()
                .id(99L)
                .customer(customer)
                .amount(new BigDecimal("12.50"))
                .referenceNumber("COLLECT-1-KEY-001")
                .status(Payment.PaymentStatus.COMPLETED)
                .build();

        when(paymentRepository.findByReferenceNumber("COLLECT-1-KEY-001"))
                .thenReturn(Optional.of(existing));
        when(allocationRepository.findByCustomerIdOrderByCreatedAtDesc(1L)).thenReturn(List.of());

        CreditCollectionDtos.CollectRequest request = new CreditCollectionDtos.CollectRequest();
        request.setAmount(new BigDecimal("12.50"));
        request.setPaymentMethod("CASH");
        request.setStrategy("FIFO");
        request.setIdempotencyKey("KEY-001");

        CreditCollectionDtos.CollectResponse response = service.collect(1L, request);

        assertNotNull(response);
        assertEquals(99L, response.getPaymentId());
        assertEquals("PAY-00099", response.getReferenceNumber());
        verify(paymentRepository, never()).save(any(Payment.class));
    }

    @Test
    void collect_withManualAllocations_appliesManualRows() {
        CustomerCreditOpeningBalance opening = new CustomerCreditOpeningBalance();
        opening.setId(11L);
        opening.setCustomer(customer);
        opening.setRemainingAmount(new BigDecimal("20.00"));
        opening.setCreatedAt(Instant.parse("2026-01-01T00:00:00Z"));

        Sale creditSale = new Sale();
        creditSale.setId(21L);
        creditSale.setCustomer(customer);
        creditSale.setSaleNumber("INV-21");
        creditSale.setStatus("CREDIT");
        creditSale.setGrandTotal(new BigDecimal("50.00"));
        creditSale.setPaidAmount(new BigDecimal("10.00"));
        creditSale.setCreditDueAt(Instant.parse("2026-02-01T00:00:00Z"));
        creditSale.setCreatedAt(Instant.parse("2026-01-15T00:00:00Z"));

        Payment savedPayment = Payment.builder()
                .id(701L)
                .customer(customer)
                .amount(new BigDecimal("15.00"))
                .referenceNumber("COLLECT-1-MAN-001")
                .status(Payment.PaymentStatus.COMPLETED)
                .build();

        when(paymentRepository.findByReferenceNumber("COLLECT-1-MAN-001"))
                .thenReturn(Optional.empty());
        when(openingBalanceRepository.findByCustomerIdAndRemainingAmountGreaterThanOrderByCreatedAtAsc(
                1L, BigDecimal.ZERO))
                .thenReturn(List.of(opening));
        when(saleRepository.findByCustomerIdAndStatusOrderByCreditDueAtAscCreatedAtAsc(1L, "CREDIT"))
                .thenReturn(List.of(creditSale));
        when(paymentRepository.save(any(Payment.class))).thenReturn(savedPayment);
        when(saleRepository.findByIdForUpdate(21L)).thenReturn(Optional.of(creditSale));
        when(openingBalanceRepository.findByIdForUpdate(11L)).thenReturn(Optional.of(opening));
        when(allocationRepository.findByCustomerIdOrderByCreatedAtDesc(1L)).thenReturn(List.of());

        CreditCollectionDtos.AllocationInput saleInput = new CreditCollectionDtos.AllocationInput();
        saleInput.setTargetType("SALE");
        saleInput.setSaleId(21L);
        saleInput.setAllocatedAmount(new BigDecimal("10.00"));

        CreditCollectionDtos.AllocationInput openingInput = new CreditCollectionDtos.AllocationInput();
        openingInput.setTargetType("OPENING_BALANCE");
        openingInput.setOpeningBalanceId(11L);
        openingInput.setAllocatedAmount(new BigDecimal("5.00"));

        CreditCollectionDtos.CollectRequest request = new CreditCollectionDtos.CollectRequest();
        request.setAmount(new BigDecimal("15.00"));
        request.setPaymentMethod("CASH");
        request.setIdempotencyKey("MAN-001");
        request.setAllocations(List.of(saleInput, openingInput));

        CreditCollectionDtos.CollectResponse response = service.collect(1L, request);
        assertEquals(701L, response.getPaymentId());
        verify(paymentRepository).save(any(Payment.class));
        verify(saleRepository).save(any(Sale.class));
        verify(openingBalanceRepository).save(any(CustomerCreditOpeningBalance.class));
    }

    @Test
    void collect_withManualAllocations_sumMismatch_throwsApiException() {
        CustomerCreditOpeningBalance opening = new CustomerCreditOpeningBalance();
        opening.setId(11L);
        opening.setCustomer(customer);
        opening.setRemainingAmount(new BigDecimal("50.00"));
        when(openingBalanceRepository.findByCustomerIdAndRemainingAmountGreaterThanOrderByCreatedAtAsc(
                1L, BigDecimal.ZERO))
                .thenReturn(List.of(opening));
        when(saleRepository.findByCustomerIdAndStatusOrderByCreditDueAtAscCreatedAtAsc(1L, "CREDIT"))
                .thenReturn(List.of());
        when(paymentRepository.findByReferenceNumber("COLLECT-1-BAD-001"))
                .thenReturn(Optional.empty());

        CreditCollectionDtos.AllocationInput openingInput = new CreditCollectionDtos.AllocationInput();
        openingInput.setTargetType("OPENING_BALANCE");
        openingInput.setOpeningBalanceId(11L);
        openingInput.setAllocatedAmount(new BigDecimal("5.00"));

        CreditCollectionDtos.CollectRequest request = new CreditCollectionDtos.CollectRequest();
        request.setAmount(new BigDecimal("10.00"));
        request.setPaymentMethod("CASH");
        request.setIdempotencyKey("BAD-001");
        request.setAllocations(List.of(openingInput));

        ApiException exception = assertThrows(ApiException.class, () -> service.collect(1L, request));
        assertTrue(exception.getMessage().contains("Manual allocation total"));
    }

    @Test
    void collect_withManualAllocations_duplicateTarget_throwsApiException() {
        CustomerCreditOpeningBalance opening = new CustomerCreditOpeningBalance();
        opening.setId(11L);
        opening.setCustomer(customer);
        opening.setRemainingAmount(new BigDecimal("50.00"));
        when(openingBalanceRepository.findByCustomerIdAndRemainingAmountGreaterThanOrderByCreatedAtAsc(
                1L, BigDecimal.ZERO))
                .thenReturn(List.of(opening));
        when(saleRepository.findByCustomerIdAndStatusOrderByCreditDueAtAscCreatedAtAsc(1L, "CREDIT"))
                .thenReturn(List.of());
        when(paymentRepository.findByReferenceNumber("COLLECT-1-DUP-001"))
                .thenReturn(Optional.empty());

        CreditCollectionDtos.AllocationInput first = new CreditCollectionDtos.AllocationInput();
        first.setTargetType("OPENING_BALANCE");
        first.setOpeningBalanceId(11L);
        first.setAllocatedAmount(new BigDecimal("5.00"));

        CreditCollectionDtos.AllocationInput second = new CreditCollectionDtos.AllocationInput();
        second.setTargetType("OPENING_BALANCE");
        second.setOpeningBalanceId(11L);
        second.setAllocatedAmount(new BigDecimal("5.00"));

        CreditCollectionDtos.CollectRequest request = new CreditCollectionDtos.CollectRequest();
        request.setAmount(new BigDecimal("10.00"));
        request.setPaymentMethod("CASH");
        request.setIdempotencyKey("DUP-001");
        request.setAllocations(List.of(first, second));

        ApiException exception = assertThrows(ApiException.class, () -> service.collect(1L, request));
        assertTrue(exception.getMessage().contains("Duplicate allocation target"));
    }

    @Test
    void collect_withManualAllocations_exceedsOutstanding_throwsApiException() {
        Sale creditSale = new Sale();
        creditSale.setId(21L);
        creditSale.setCustomer(customer);
        creditSale.setStatus("CREDIT");
        creditSale.setGrandTotal(new BigDecimal("20.00"));
        creditSale.setPaidAmount(new BigDecimal("10.00"));
        when(openingBalanceRepository.findByCustomerIdAndRemainingAmountGreaterThanOrderByCreatedAtAsc(
                1L, BigDecimal.ZERO))
                .thenReturn(List.of());
        when(saleRepository.findByCustomerIdAndStatusOrderByCreditDueAtAscCreatedAtAsc(1L, "CREDIT"))
                .thenReturn(List.of(creditSale));
        when(paymentRepository.findByReferenceNumber("COLLECT-1-EXCESS-001"))
                .thenReturn(Optional.empty());

        CreditCollectionDtos.AllocationInput saleInput = new CreditCollectionDtos.AllocationInput();
        saleInput.setTargetType("SALE");
        saleInput.setSaleId(21L);
        saleInput.setAllocatedAmount(new BigDecimal("15.00"));

        CreditCollectionDtos.CollectRequest request = new CreditCollectionDtos.CollectRequest();
        request.setAmount(new BigDecimal("15.00"));
        request.setPaymentMethod("CASH");
        request.setIdempotencyKey("EXCESS-001");
        request.setAllocations(List.of(saleInput));

        ApiException exception = assertThrows(ApiException.class, () -> service.collect(1L, request));
        assertTrue(exception.getMessage().contains("Allocation exceeds outstanding amount"));
    }

    @Test
    void createOpeningBalance_whenOneAlreadyExists_throwsApiException() {
        when(openingBalanceRepository.existsByCustomerId(1L)).thenReturn(true);

        com.kaknnea.pos.dto.CustomerDtos.OpeningBalanceRequest request =
                new com.kaknnea.pos.dto.CustomerDtos.OpeningBalanceRequest();
        request.setAmount(new BigDecimal("25.00"));
        request.setNote("Second opening balance");

        ApiException exception = assertThrows(ApiException.class, () -> service.createOpeningBalance(1L, request));
        assertTrue(exception.getMessage().contains("Opening balance already exists"));
        verify(openingBalanceRepository, never()).save(any(CustomerCreditOpeningBalance.class));
    }

    @Test
    void createAdjustment_requiresReason() {
        CreditCollectionDtos.AdjustmentRequest request = new CreditCollectionDtos.AdjustmentRequest();
        request.setType("DEBIT_NOTE");
        request.setAmount(new BigDecimal("25.00"));
        request.setReason("  ");

        ApiException exception = assertThrows(ApiException.class, () -> service.createAdjustment(1L, request));
        assertTrue(exception.getMessage().contains("reason is required"));
    }

    @Test
    void createCreditNote_cannotExceedOutstandingBalance() {
        CreditCollectionDtos.AdjustmentRequest request = new CreditCollectionDtos.AdjustmentRequest();
        request.setType("CREDIT_NOTE");
        request.setAmount(new BigDecimal("100.00"));
        request.setReason("Over-credit");

        ApiException exception = assertThrows(ApiException.class, () -> service.createAdjustment(1L, request));
        assertTrue(exception.getMessage().contains("cannot exceed"));
    }
}
