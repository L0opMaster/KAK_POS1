package com.kaknnea.pos.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.domain.CustomerCreditAccount;
import com.kaknnea.pos.domain.Sale;
import com.kaknnea.pos.domain.Shift;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.dto.SaleDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.BusinessSettingsRepository;
import com.kaknnea.pos.repository.CustomerCreditAccountRepository;
import com.kaknnea.pos.repository.CustomerCreditAllocationRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.CurrencySettingRepository;
import com.kaknnea.pos.repository.PaymentRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.SaleDiscountRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.ShiftRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.StockMovementRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.TableRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class SaleServiceCreditTest {

    @Mock private SaleRepository saleRepository;
    @Mock private ProductRepository productRepository;
    @Mock private StockItemRepository stockItemRepository;
    @Mock private StockMovementRepository stockMovementRepository;
    @Mock private PaymentRepository paymentRepository;
    @Mock private SaleDiscountRepository saleDiscountRepository;
    @Mock private CustomerRepository customerRepository;
    @Mock private CustomerCreditAccountRepository creditAccountRepository;
    @Mock private ShiftRepository shiftRepository;
    @Mock private BusinessSettingsRepository businessSettingsRepository;
    @Mock private TableRepository tableRepository;
    @Mock private PdfService pdfService;
    @Mock private AuditService auditService;
    @Mock private CashEventService cashEventService;
    @Mock private com.kaknnea.pos.repository.UserRepository userRepository;
    @Mock private StoreRepository storeRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private PriceListService priceListService;
    @Mock private CreditCollectionService creditCollectionService;
    @Mock private CustomerCreditAllocationRepository creditAllocationRepository;
    @Mock private EmailService emailService;
    @Mock private CurrencySettingRepository currencySettingRepository;

    private SaleService service;
    private Customer customer;
    private Store store;
    private Shift shift;

    @BeforeEach
    void setUp() {
        service = new SaleService(saleRepository, productRepository, stockItemRepository,
                stockMovementRepository, paymentRepository, saleDiscountRepository,
                customerRepository, creditAccountRepository, shiftRepository,
                businessSettingsRepository, tableRepository, pdfService, auditService,
                cashEventService, userRepository, storeRepository, passwordEncoder,
                priceListService, creditCollectionService, creditAllocationRepository,
                emailService, currencySettingRepository);

        store = new Store();
        store.setId(1L);
        store.setName("Main Store");

        shift = new Shift();
        shift.setId(1L);
        shift.setStore(store);
        shift.setStatus("OPEN");

        customer = new Customer();
        customer.setId(1L);
        customer.setNameEn("Sok Dara");
        customer.setCreditLimit(BigDecimal.ZERO);
        customer.setCreditBalance(BigDecimal.ZERO);

        // resolveShiftForSaleProcessing() unconditionally resolves "the current
        // actor's open shift" before ever checking whether the sale already has
        // one — even though credit()/repayCreditSale() only need that when
        // sale.getShift() is null (see SaleService.findCurrentShiftForActor()).
        User actor = new User();
        actor.setId(99L);
        lenient().when(userRepository.findByEmail(any())).thenReturn(Optional.of(actor));
        lenient().when(shiftRepository.findFirstByOpenedByIdAndStatusOrderByOpenedAtDesc(anyLong(), any()))
                .thenReturn(Optional.empty());
        lenient().when(creditAccountRepository.findByCustomerId(anyLong())).thenReturn(Optional.empty());
        lenient().when(saleRepository.save(any(Sale.class))).thenAnswer(inv -> inv.getArgument(0));
        lenient().when(customerRepository.save(any(Customer.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private Sale creditableSale() {
        Sale sale = new Sale();
        sale.setId(10L);
        sale.setStatus("DRAFT");
        sale.setCustomer(customer);
        sale.setShift(shift);
        sale.setGrandTotal(new BigDecimal("100.00"));
        sale.setPaidAmount(BigDecimal.ZERO);
        sale.setLines(new ArrayList<>());
        return sale;
    }

    @Test
    void credit_dueDateBeforeSaleDate_rejects() {
        Sale sale = creditableSale();
        when(saleRepository.findById(10L)).thenReturn(Optional.of(sale));

        SaleDtos.CreditRequest request = new SaleDtos.CreditRequest();
        request.setDueDate(Instant.now().minus(5, ChronoUnit.DAYS).toString().substring(0, 10));

        ApiException ex = assertThrows(ApiException.class, () -> service.credit(10L, request));
        assertEquals("Due date cannot be before the sale date", ex.getMessage());
    }

    @Test
    void credit_expiresBeforeDueDate_rejects() {
        Sale sale = creditableSale();
        when(saleRepository.findById(10L)).thenReturn(Optional.of(sale));

        String due = Instant.now().plus(30, ChronoUnit.DAYS).toString().substring(0, 10);
        String expires = Instant.now().plus(10, ChronoUnit.DAYS).toString().substring(0, 10);
        SaleDtos.CreditRequest request = new SaleDtos.CreditRequest();
        request.setDueDate(due);
        request.setExpiresAt(expires);

        ApiException ex = assertThrows(ApiException.class, () -> service.credit(10L, request));
        assertEquals("Expiration date cannot be before the due date", ex.getMessage());
    }

    @Test
    void credit_withExplicitDueDate_setsCreditDueAtAndBalance() {
        Sale sale = creditableSale();
        when(saleRepository.findById(10L)).thenReturn(Optional.of(sale));

        String due = Instant.now().plus(45, ChronoUnit.DAYS).toString().substring(0, 10);
        SaleDtos.CreditRequest request = new SaleDtos.CreditRequest();
        request.setDueDate(due);
        request.setNotes("Customer requested extended term");

        SaleDtos.SaleResponse resp = service.credit(10L, request);

        assertEquals("CREDIT", resp.getStatus());
        assertEquals(new BigDecimal("100.00"), customer.getCreditBalance());
        assertEquals("Customer requested extended term", sale.getNote());
    }

    @Test
    void credit_noBody_legacyBehaviorUnchanged() {
        Sale sale = creditableSale();
        sale.setPaymentTerms("CREDIT"); // legacy parseCreditTermDays("CREDIT") -> 30 days
        when(saleRepository.findById(10L)).thenReturn(Optional.of(sale));

        SaleDtos.SaleResponse resp = service.credit(10L, null);

        assertEquals("CREDIT", resp.getStatus());
        assertEquals(Integer.valueOf(30), sale.getCreditTermDays());
    }

    @Test
    void repayCreditSale_amountExceedsRemaining_rejects() {
        Sale sale = creditableSale();
        sale.setStatus("CREDIT");
        sale.setPaidAmount(new BigDecimal("20.00"));
        when(saleRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(sale));

        SaleDtos.CreditRepaymentRequest request = new SaleDtos.CreditRepaymentRequest();
        request.setAmount(new BigDecimal("999.00"));
        request.setMethod("CASH");

        ApiException ex = assertThrows(ApiException.class, () -> service.repayCreditSale(10L, request));
        assertEquals("Repayment exceeds remaining balance", ex.getMessage());
    }

    @Test
    void repayCreditSale_usesLockedFindByIdForUpdate_notPlainFindById() {
        Sale sale = creditableSale();
        sale.setStatus("CREDIT");
        when(saleRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(sale));
        when(paymentRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SaleDtos.CreditRepaymentRequest request = new SaleDtos.CreditRepaymentRequest();
        request.setAmount(new BigDecimal("50.00"));
        request.setMethod("CASH");

        service.repayCreditSale(10L, request);

        verify(saleRepository, times(1)).findByIdForUpdate(10L);
        verify(saleRepository, never()).findById(10L);
    }

    @Test
    void voidSale_creditSaleWithRecordedRepayments_rejects() {
        Sale sale = creditableSale();
        sale.setStatus("CREDIT");
        sale.setCreditIssuedAt(Instant.now());
        sale.setPaidAmount(new BigDecimal("30.00"));
        when(saleRepository.findById(10L)).thenReturn(Optional.of(sale));

        ApiException ex = assertThrows(ApiException.class, () -> service.voidSale(10L, "customer changed mind"));
        assertEquals("Cannot void a credit sale with recorded repayments — refund instead", ex.getMessage());
    }

    @Test
    void voidSale_creditSaleWithNoRepayments_reversesCustomerBalance() {
        Sale sale = creditableSale();
        sale.setStatus("CREDIT");
        sale.setCreditIssuedAt(Instant.now());
        sale.setPaidAmount(BigDecimal.ZERO);
        customer.setCreditBalance(new BigDecimal("100.00"));
        when(saleRepository.findById(10L)).thenReturn(Optional.of(sale));

        SaleDtos.SaleResponse resp = service.voidSale(10L, "duplicate order");

        assertEquals("VOID", resp.getStatus());
        assertEquals(0, customer.getCreditBalance().compareTo(BigDecimal.ZERO));
        verify(creditCollectionService).syncBalanceForCustomer(customer.getId());
    }

    @Test
    void voidSale_plainNonCreditSale_unaffectedByNewGuard() {
        Sale sale = creditableSale();
        sale.setStatus("PAID");
        sale.setPaidAmount(new BigDecimal("100.00"));
        when(saleRepository.findById(10L)).thenReturn(Optional.of(sale));

        SaleDtos.SaleResponse resp = service.voidSale(10L, "refund requested");

        assertEquals("VOID", resp.getStatus());
        assertNull(sale.getCreditIssuedAt());
    }
}
