package com.kaknnea.pos.service;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.kaknnea.pos.domain.SaleLine;
import com.kaknnea.pos.repository.BusinessSettingsRepository;
import com.kaknnea.pos.repository.CurrencySettingRepository;
import com.kaknnea.pos.repository.CustomerCreditAccountRepository;
import com.kaknnea.pos.repository.CustomerCreditAllocationRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.PaymentRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.SaleDiscountRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.ShiftRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.StockMovementRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.TableRepository;
import com.kaknnea.pos.repository.UserRepository;
import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * Tests SaleService's per-product tax calculation ({@code computeLineTaxes}/
 * {@code blendedTaxRate}) in isolation via reflection — these are pure
 * functions of their arguments (no repository access), so there's no need to
 * mock the rest of the create()/update()/createEstimate() pipeline just to
 * exercise the tax math itself.
 */
@ExtendWith(MockitoExtension.class)
class SaleServiceTaxTest {

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
    @Mock private UserRepository userRepository;
    @Mock private StoreRepository storeRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private PriceListService priceListService;
    @Mock private CreditCollectionService creditCollectionService;
    @Mock private CustomerCreditAllocationRepository creditAllocationRepository;
    @Mock private EmailService emailService;
    @Mock private CurrencySettingRepository currencySettingRepository;

    private SaleService service;

    @BeforeEach
    void setUp() {
        service = new SaleService(saleRepository, productRepository, stockItemRepository,
                stockMovementRepository, paymentRepository, saleDiscountRepository,
                customerRepository, creditAccountRepository, shiftRepository,
                businessSettingsRepository, tableRepository, pdfService, auditService,
                cashEventService, userRepository, storeRepository, passwordEncoder,
                priceListService, creditCollectionService, creditAllocationRepository,
                emailService, currencySettingRepository);
    }

    private SaleLine line(String lineTotal, String taxRate) {
        SaleLine line = new SaleLine();
        line.setLineTotal(new BigDecimal(lineTotal));
        line.setTaxRate(Double.parseDouble(taxRate));
        return line;
    }

    private BigDecimal computeLineTaxes(List<SaleLine> lines, BigDecimal subtotal, BigDecimal discount) {
        return ReflectionTestUtils.invokeMethod(service, "computeLineTaxes", lines, subtotal, discount);
    }

    private double blendedTaxRate(BigDecimal taxable, BigDecimal taxAmount) {
        return ReflectionTestUtils.invokeMethod(service, "blendedTaxRate", taxable, taxAmount);
    }

    @Test
    void sumsEachLinesOwnTaxAtItsOwnRate_noDiscount() {
        // Iced Coffee 3.00 @ 8%, Donuts 6.00 @ 0% (tax-exempt)
        List<SaleLine> lines = List.of(line("3.00", "0.08"), line("6.00", "0.00"));
        BigDecimal subtotal = new BigDecimal("9.00");

        BigDecimal tax = computeLineTaxes(lines, subtotal, BigDecimal.ZERO);

        assertEquals(0, tax.compareTo(new BigDecimal("0.24")),
                "only the 8% line should contribute tax: 3.00 * 0.08 = 0.24");
    }

    @Test
    void zeroTaxRateProductContributesNoTax() {
        List<SaleLine> lines = List.of(line("100.00", "0.00"));
        BigDecimal tax = computeLineTaxes(lines, new BigDecimal("100.00"), BigDecimal.ZERO);
        assertEquals(0, tax.compareTo(BigDecimal.ZERO));
    }

    @Test
    void invoiceDiscountIsProratedAcrossLinesBeforeTaxing() {
        // Two identical-price lines at different rates; a $10 invoice discount should
        // reduce each line's taxable base by its proportional share (50/50 here),
        // not apply entirely to one line or ignore the split.
        List<SaleLine> lines = List.of(line("50.00", "0.10"), line("50.00", "0.20"));
        BigDecimal subtotal = new BigDecimal("100.00");
        BigDecimal discount = new BigDecimal("10.00");

        // Each line: 50 - (10 * 0.5) = 45 taxable.
        // Line 1: 45 * 0.10 = 4.50, Line 2: 45 * 0.20 = 9.00 -> 13.50 total.
        BigDecimal tax = computeLineTaxes(lines, subtotal, discount);

        assertEquals(0, tax.compareTo(new BigDecimal("13.50")));
    }

    @Test
    void emptySubtotal_returnsZeroTaxWithoutDividingByZero() {
        BigDecimal tax = computeLineTaxes(List.of(), BigDecimal.ZERO, BigDecimal.ZERO);
        assertEquals(0, tax.compareTo(BigDecimal.ZERO));
    }

    @Test
    void blendedTaxRate_derivesEffectiveRateForDisplay() {
        // 0.24 tax on 9.00 taxable -> effective ~2.67%, matching a mixed 8%/0% cart.
        double rate = blendedTaxRate(new BigDecimal("9.00"), new BigDecimal("0.24"));
        assertEquals(0.24 / 9.00, rate, 0.0001);
    }

    @Test
    void blendedTaxRate_zeroTaxableReturnsZeroWithoutDividingByZero() {
        assertEquals(0.0, blendedTaxRate(BigDecimal.ZERO, BigDecimal.ZERO));
    }
}
