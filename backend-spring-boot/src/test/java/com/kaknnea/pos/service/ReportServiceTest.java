package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.Sale;
import com.kaknnea.pos.domain.SaleLine;
import com.kaknnea.pos.domain.Shift;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.dto.ReportDtos;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.ShiftRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ReportServiceTest {

    @Mock
    private SaleRepository saleRepository;

    @Mock
    private ShiftRepository shiftRepository;

    @InjectMocks
    private ReportService reportService;

    private Shift testShift;
    private Sale testSale;

    @BeforeEach
    void setUp() {
        User testUser = new User();
        testUser.setId(1L);
        testUser.setFullName("Test User");

        testShift = new Shift();
        testShift.setId(1L);
        testShift.setStatus("OPEN");
        testShift.setOpenedAt(Instant.now());
        testShift.setOpenedBy(testUser);
        testShift.setOpeningCash(BigDecimal.valueOf(100.00));
        testShift.setClosingCash(BigDecimal.valueOf(150.00));

        testSale = new Sale();
        testSale.setId(1L);
        testSale.setStatus("PAID");
        testSale.setGrandTotal(BigDecimal.valueOf(50.00));
    }

    @Test
    void getShiftSummary_ShouldReturnSummary_WhenShiftExists() {
        // Given
        when(shiftRepository.findById(1L)).thenReturn(Optional.of(testShift));
        when(saleRepository.findByShiftIdAndStatus(1L, "PAID")).thenReturn(List.of(testSale));

        // When
        Map<String, Object> result = reportService.getShiftSummary(1L);

        // Then
        assertThat(result).isNotNull();
        assertThat(result.get("shiftId")).isEqualTo(1L);
        assertThat(result.get("status")).isEqualTo("OPEN");
        assertThat(result.get("totalSales")).isEqualTo(BigDecimal.valueOf(50.00));
        assertThat(result.get("salesCount")).isEqualTo(1);
    }

    @Test
    void getShiftSummary_ShouldThrowException_WhenShiftNotFound() {
        // Given
        when(shiftRepository.findById(999L)).thenReturn(Optional.empty());

        // When & Then
        assertThatThrownBy(() -> reportService.getShiftSummary(999L))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("Shift not found");
    }

    @Test
    void salesByItemReport_paginatesAndSortsByNetSalesDescending() {
        LocalDate from = LocalDate.of(2026, 3, 1);
        LocalDate to = LocalDate.of(2026, 3, 1);

        Product coffee = product(1L, "Coffee", "កាហ្វេ", "SKU-A");
        Product tea = product(2L, "Tea", "តែ", "SKU-B");

        Sale saleA = saleWithLine(1L, coffee, new BigDecimal("2"), new BigDecimal("10.00"),
                Instant.parse("2026-03-01T05:00:00Z"));
        Sale saleB = saleWithLine(2L, tea, new BigDecimal("1"), new BigDecimal("50.00"),
                Instant.parse("2026-03-01T06:00:00Z"));

        when(saleRepository.findReportSalesByInvoiceDate(eq(from), eq(to), any(), any(), any()))
                .thenReturn(List.of(saleA, saleB));

        // page size 1 -> only the top row (by net sales) should come back, but totalElements
        // should still reflect the full unpaginated result set.
        Page<ReportDtos.SalesByItemRow> page = reportService.salesByItemReport(from, to, null, null, null, 0, 1,
                "revenue");

        assertThat(page.getTotalElements()).isEqualTo(2);
        assertThat(page.getTotalPages()).isEqualTo(2);
        assertThat(page.getContent()).hasSize(1);
        assertThat(page.getContent().get(0).getProductId()).isEqualTo(2L);
        assertThat(page.getContent().get(0).getNetSales()).isEqualByComparingTo("50.00");
    }

    @Test
    void categoryPerformance_hourRangeExcludesOutOfRangeSales() {
        LocalDate from = LocalDate.of(2026, 3, 1);
        LocalDate to = LocalDate.of(2026, 3, 1);

        Category category = new Category();
        category.setId(1L);
        category.setNameEn("Drinks");
        category.setNameKm("ភេសជ្ជៈ");

        Product product = product(1L, "Coffee", "កាហ្វេ", "SKU-A");
        product.setCategory(category);

        ZoneId reportZone = ZoneId.of("Asia/Phnom_Penh");
        Instant morning = ZonedDateTime.of(2026, 3, 1, 8, 0, 0, 0, reportZone).toInstant();
        Instant evening = ZonedDateTime.of(2026, 3, 1, 20, 0, 0, 0, reportZone).toInstant();

        Sale morningSale = saleWithLine(1L, product, new BigDecimal("1"), new BigDecimal("5.00"), morning);
        Sale eveningSale = saleWithLine(2L, product, new BigDecimal("1"), new BigDecimal("5.00"), evening);

        when(saleRepository.findReportSalesByCreatedAt(any(), any(), any()))
                .thenReturn(List.of(morningSale, eveningSale));

        Page<ReportDtos.CategoryPerformance> page = reportService.categoryPerformance(from, to, 6, 10, null, 0, 20);

        assertThat(page.getTotalElements()).isEqualTo(1);
        assertThat(page.getContent().get(0).getQuantity()).isEqualByComparingTo("1");
    }

    @Test
    void cashierPerformance_filtersByEmployeeIdAndPaginates() {
        LocalDate from = LocalDate.of(2026, 3, 1);
        LocalDate to = LocalDate.of(2026, 3, 1);

        User cashierOne = user(1L, "Cashier One");
        User cashierTwo = user(2L, "Cashier Two");

        Sale saleByCashierOne = new Sale();
        saleByCashierOne.setId(1L);
        saleByCashierOne.setStatus("PAID");
        saleByCashierOne.setCreatedBy(cashierOne);
        saleByCashierOne.setCreatedAt(Instant.parse("2026-03-01T05:00:00Z"));
        saleByCashierOne.setGrandTotal(new BigDecimal("20.00"));
        saleByCashierOne.setLines(List.of());

        Sale saleByCashierTwo = new Sale();
        saleByCashierTwo.setId(2L);
        saleByCashierTwo.setStatus("PAID");
        saleByCashierTwo.setCreatedBy(cashierTwo);
        saleByCashierTwo.setCreatedAt(Instant.parse("2026-03-01T06:00:00Z"));
        saleByCashierTwo.setGrandTotal(new BigDecimal("40.00"));
        saleByCashierTwo.setLines(List.of());

        when(saleRepository.findReportSalesByInvoiceDate(eq(from), eq(to), any(), any(), any()))
                .thenReturn(List.of(saleByCashierOne, saleByCashierTwo));

        Page<ReportDtos.CashierPerformance> page = reportService.cashierPerformance(from, to, null, null, 1L, 0, 20);

        assertThat(page.getTotalElements()).isEqualTo(1);
        assertThat(page.getContent().get(0).getCashierId()).isEqualTo(1L);
        assertThat(page.getContent().get(0).getSalesTotal()).isEqualByComparingTo("20.00");
    }

    @Test
    void salesByModifierReport_aggregatesByOptionNameAndSkipsMalformedJson() {
        LocalDate from = LocalDate.of(2026, 3, 1);
        LocalDate to = LocalDate.of(2026, 3, 1);

        Product product = product(1L, "Latte", "តែ", "SKU-L");

        SaleLine validLine = new SaleLine();
        validLine.setProduct(product);
        validLine.setQuantity(new BigDecimal("2"));
        validLine.setUnitPrice(new BigDecimal("3.00"));
        validLine.setLineDiscount(BigDecimal.ZERO);
        validLine.setLineTotal(new BigDecimal("6.00"));
        validLine.setModifierData(
                "[{\"groupId\":1,\"groupName\":\"Size\",\"optionId\":10,\"optionName\":\"Large\",\"priceDelta\":1.50}]");

        SaleLine malformedLine = new SaleLine();
        malformedLine.setProduct(product);
        malformedLine.setQuantity(new BigDecimal("3"));
        malformedLine.setUnitPrice(new BigDecimal("3.00"));
        malformedLine.setLineDiscount(BigDecimal.ZERO);
        malformedLine.setLineTotal(new BigDecimal("9.00"));
        malformedLine.setModifierData("this is not valid json");

        Sale sale = new Sale();
        sale.setId(1L);
        sale.setStatus("PAID");
        sale.setCreatedAt(Instant.parse("2026-03-01T05:00:00Z"));
        sale.setLines(List.of(validLine, malformedLine));

        when(saleRepository.findReportSalesByInvoiceDate(eq(from), eq(to), any(), any(), any()))
                .thenReturn(List.of(sale));

        Page<ReportDtos.ModifierPerformance> page = reportService.salesByModifierReport(from, to, null, null, null,
                0, 20);

        assertThat(page.getTotalElements()).isEqualTo(1);
        ReportDtos.ModifierPerformance perf = page.getContent().get(0);
        assertThat(perf.getGroupName()).isEqualTo("Size");
        assertThat(perf.getOptionName()).isEqualTo("Large");
        assertThat(perf.getQuantity()).isEqualByComparingTo("2");
        assertThat(perf.getRevenue()).isEqualByComparingTo("3.00");
    }

    private Product product(Long id, String nameEn, String nameKm, String sku) {
        Product product = new Product();
        product.setId(id);
        product.setNameEn(nameEn);
        product.setNameKm(nameKm);
        product.setSku(sku);
        return product;
    }

    private User user(Long id, String fullName) {
        User user = new User();
        user.setId(id);
        user.setFullName(fullName);
        return user;
    }

    private Sale saleWithLine(Long id, Product product, BigDecimal quantity, BigDecimal unitPrice, Instant createdAt) {
        SaleLine line = new SaleLine();
        line.setProduct(product);
        line.setQuantity(quantity);
        line.setUnitPrice(unitPrice);
        line.setLineDiscount(BigDecimal.ZERO);
        line.setLineTotal(unitPrice.multiply(quantity));

        Sale sale = new Sale();
        sale.setId(id);
        sale.setStatus("PAID");
        sale.setCreatedAt(createdAt);
        sale.setLines(List.of(line));
        sale.setGrandTotal(unitPrice.multiply(quantity));
        return sale;
    }
}