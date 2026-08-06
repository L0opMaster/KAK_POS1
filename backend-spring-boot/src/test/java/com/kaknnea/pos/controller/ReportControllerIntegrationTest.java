package com.kaknnea.pos.controller;

import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.domain.Expense;
import com.kaknnea.pos.domain.ExpenseCategory;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.domain.Supplier;
import com.kaknnea.pos.domain.Unit;
import com.kaknnea.pos.repository.CategoryRepository;
import com.kaknnea.pos.repository.ExpenseCategoryRepository;
import com.kaknnea.pos.repository.ExpenseRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.SupplierRepository;
import com.kaknnea.pos.repository.UnitRepository;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class ReportControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private SupplierRepository supplierRepository;

    @Autowired
    private StoreRepository storeRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private UnitRepository unitRepository;

    @Autowired
    private ExpenseRepository expenseRepository;

    @Autowired
    private ExpenseCategoryRepository expenseCategoryRepository;

    @Test
    @WithMockUser(authorities = "PERM_REPORTS_VIEW")
    void salesSummaryEndpoint_returnsExpectedShape() throws Exception {
        mockMvc.perform(get("/api/reports/sales-summary")
                        .param("from", "2026-03-01")
                        .param("to", "2026-03-05"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fromDate").value("2026-03-01"))
                .andExpect(jsonPath("$.toDate").value("2026-03-05"))
                .andExpect(jsonPath("$.rows.content").isArray())
                .andExpect(jsonPath("$.rows.totalElements").exists())
                .andExpect(jsonPath("$.rows.totalPages").exists())
                .andExpect(jsonPath("$.rows.number").value(0))
                .andExpect(jsonPath("$.rows.size").value(20))
                .andExpect(jsonPath("$.stores").isArray())
                .andExpect(jsonPath("$.cashiers").isArray())
                .andExpect(jsonPath("$.payments").isArray())
                .andExpect(jsonPath("$.totals").exists())
                .andExpect(jsonPath("$.totals.totalSales").exists())
                .andExpect(jsonPath("$.totals.gross").exists())
                .andExpect(jsonPath("$.totals.discount").exists())
                .andExpect(jsonPath("$.totals.tax").exists())
                .andExpect(jsonPath("$.totals.net").exists())
                .andExpect(jsonPath("$.totals.orders").exists())
                .andExpect(jsonPath("$.totals.quantity").exists());
    }

    @Test
    @WithMockUser(authorities = { "PERM_REPORTS_VIEW", "PERM_PURCHASE_MANAGE" })
    void purchaseSummaryEndpoint_returnsProcurementTotalsFromRealWorkflow() throws Exception {
        Supplier supplier = createSupplier();
        Store store = createStore("Report Store");
        Product product = createPurchasableTrackedProduct("PUR-RPT-" + System.nanoTime(), "Report Beans");
        LocalDate today = LocalDate.now();
        LocalDate invoiceDate = today.plusDays(1);

        String poResponse = mockMvc.perform(post("/api/purchase-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "storeId": %d,
                                  "taxRate": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 5, "unitCost": 10 }
                                  ]
                                }
                                """.formatted(supplier.getId(), store.getId(), product.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long purchaseOrderId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.id")).longValue();
        long purchaseOrderLineId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.lines[0].id")).longValue();

        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/submit"))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/approve"))
                .andExpect(status().isOk());

        String grnResponse = mockMvc.perform(post("/api/goods-receipts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "purchaseOrderId": %d,
                                  "storeId": %d,
                                  "lines": [
                                    { "purchaseOrderLineId": %d, "productId": %d, "quantity": 3, "unitCost": 10 }
                                  ]
                                }
                                """.formatted(purchaseOrderId, store.getId(), purchaseOrderLineId, product.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long goodsReceiptId = ((Number) com.jayway.jsonpath.JsonPath.read(grnResponse, "$.id")).longValue();

        String invoiceResponse = mockMvc.perform(post("/api/supplier-invoices")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "purchaseOrderId": %d,
                                  "goodsReceiptId": %d,
                                  "invoiceNumber": "INV-RPT-1",
                                  "invoiceDate": "%s",
                                  "taxAmount": 3,
                                  "lines": [
                                    { "productId": %d, "quantity": 3, "unitCost": 10 }
                                  ]
                                }
                                """.formatted(supplier.getId(), purchaseOrderId, goodsReceiptId, invoiceDate, product.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long invoiceId = ((Number) com.jayway.jsonpath.JsonPath.read(invoiceResponse, "$.id")).longValue();

        mockMvc.perform(post("/api/supplier-payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierInvoiceId": %d,
                                  "amount": 10,
                                  "reference": "PAY-RPT-1"
                                }
                                """.formatted(invoiceId)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/reports/purchase-summary")
                        .param("from", today.minusDays(1).toString())
                        .param("to", today.plusDays(1).toString())
                        .param("storeId", String.valueOf(store.getId()))
                        .param("supplierId", String.valueOf(supplier.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fromDate").value(today.minusDays(1).toString()))
                .andExpect(jsonPath("$.toDate").value(today.plusDays(1).toString()))
                .andExpect(jsonPath("$.rows").isArray())
                .andExpect(jsonPath("$.rows.length()", is(2)))
                .andExpect(jsonPath("$.stores").isArray())
                .andExpect(jsonPath("$.suppliers").isArray())
                .andExpect(jsonPath("$.rows[0].purchaseOrders", is(1)))
                .andExpect(jsonPath("$.rows[0].goodsReceipts", is(1)))
                .andExpect(jsonPath("$.rows[0].orderedValue", is(50.00)))
                .andExpect(jsonPath("$.rows[0].receivedValue", is(30)))
                .andExpect(jsonPath("$.rows[1].supplierBills", is(1)))
                .andExpect(jsonPath("$.rows[1].billedValue", is(33)))
                .andExpect(jsonPath("$.rows[1].paidValue", is(10)))
                .andExpect(jsonPath("$.rows[1].outstandingValue", is(23)))
                .andExpect(jsonPath("$.totals.purchaseOrders", is(1)))
                .andExpect(jsonPath("$.totals.goodsReceipts", is(1)))
                .andExpect(jsonPath("$.totals.supplierBills", is(1)))
                .andExpect(jsonPath("$.totals.suppliers", is(1)))
                .andExpect(jsonPath("$.totals.orderedValue", is(50.00)))
                .andExpect(jsonPath("$.totals.receivedValue", is(30)))
                .andExpect(jsonPath("$.totals.billedValue", is(33)))
                .andExpect(jsonPath("$.totals.paidValue", is(10)))
                .andExpect(jsonPath("$.totals.outstandingValue", is(23)))
                .andExpect(jsonPath("$.totals.openCommitmentValue", is(50.00)));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_REPORTS_VIEW", "PERM_PURCHASE_MANAGE", "PERM_POS_SALE", "PERM_SHIFT_MANAGE"
    })
    void paymentInOutEndpoint_returnsIncomingAndOutgoingMovements() throws Exception {
        Supplier supplier = createSupplier();
        Store store = createStore("Payment Report Store");
        Product saleProduct = createSellableNonTrackedProduct("PAY-SALE-" + System.nanoTime(), "Payment Sale Item");
        Product purchaseProduct = createPurchasableTrackedProduct("PAY-RPT-" + System.nanoTime(), "Payment Report Item");
        LocalDate today = LocalDate.now();

        mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "openingCash": 100,
                                  "storeId": %d
                                }
                                """.formatted(store.getId())))
                .andExpect(status().isOk());

        String saleResponse = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "taxRate": 0,
                                  "invoiceDiscount": 0,
                                  "clientRef": "payment-report-sale",
                                  "lines": [
                                    { "productId": %d, "quantity": 1, "unitPrice": 12, "lineDiscount": 0 }
                                  ]
                                }
                                """.formatted(saleProduct.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long saleId = ((Number) com.jayway.jsonpath.JsonPath.read(saleResponse, "$.id")).longValue();
        String invoiceNumber = com.jayway.jsonpath.JsonPath.read(saleResponse, "$.invoiceNumber");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "payments": [
                                    { "method": "CASH", "amount": 12 }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PAID"));

        String poResponse = mockMvc.perform(post("/api/purchase-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "storeId": %d,
                                  "taxRate": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 2, "unitCost": 10 }
                                  ]
                                }
                                """.formatted(supplier.getId(), store.getId(), purchaseProduct.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long purchaseOrderId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.id")).longValue();
        long purchaseOrderLineId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.lines[0].id")).longValue();

        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/submit"))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/approve"))
                .andExpect(status().isOk());

        String grnResponse = mockMvc.perform(post("/api/goods-receipts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "purchaseOrderId": %d,
                                  "storeId": %d,
                                  "lines": [
                                    { "purchaseOrderLineId": %d, "productId": %d, "quantity": 2, "unitCost": 10 }
                                  ]
                                }
                                """.formatted(purchaseOrderId, store.getId(), purchaseOrderLineId, purchaseProduct.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long goodsReceiptId = ((Number) com.jayway.jsonpath.JsonPath.read(grnResponse, "$.id")).longValue();

        String invoiceResponse = mockMvc.perform(post("/api/supplier-invoices")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "purchaseOrderId": %d,
                                  "goodsReceiptId": %d,
                                  "invoiceNumber": "PINOUT-INV-1",
                                  "invoiceDate": "%s",
                                  "taxAmount": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 2, "unitCost": 10 }
                                  ]
                                }
                                """.formatted(supplier.getId(), purchaseOrderId, goodsReceiptId, today, purchaseProduct.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long supplierInvoiceId = ((Number) com.jayway.jsonpath.JsonPath.read(invoiceResponse, "$.id")).longValue();

        mockMvc.perform(post("/api/supplier-payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierInvoiceId": %d,
                                  "amount": 8,
                                  "paymentMethod": "ABA",
                                  "reference": "SUP-PAY-1"
                                }
                                """.formatted(supplierInvoiceId)))
                .andExpect(status().isOk());

        String paymentReportResponse = mockMvc.perform(get("/api/reports/payment-in-out")
                        .param("from", today.minusDays(1).toString())
                        .param("to", today.plusDays(1).toString())
                        .param("storeId", String.valueOf(store.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fromDate").value(today.minusDays(1).toString()))
                .andExpect(jsonPath("$.toDate").value(today.plusDays(1).toString()))
                .andExpect(jsonPath("$.rows.length()", is(2)))
                .andExpect(jsonPath("$.rows[0].direction").exists())
                .andExpect(jsonPath("$.rows[0].sourceType").exists())
                .andExpect(jsonPath("$.rows[0].storeName").value(store.getName()))
                .andExpect(jsonPath("$.rows[0].amount").exists())
                .andExpect(jsonPath("$.rows[1].storeName").value(store.getName()))
                .andExpect(jsonPath("$.totals.incomingAmount").value(12))
                .andExpect(jsonPath("$.totals.outgoingAmount").value(8))
                .andExpect(jsonPath("$.totals.netAmount").value(4))
                .andExpect(jsonPath("$.totals.incomingCount").value(1))
                .andExpect(jsonPath("$.totals.outgoingCount").value(1))
                .andExpect(jsonPath("$.totals.totalCount").value(2))
                .andExpect(jsonPath("$.stores").isArray())
                .andExpect(jsonPath("$.methods").isArray())
                .andReturn()
                .getResponse()
                .getContentAsString();

        List<Map<String, Object>> rows = com.jayway.jsonpath.JsonPath.read(paymentReportResponse, "$.rows");
        assertThat(rows.size(), is(2));

        @SuppressWarnings("unchecked")
        Map<String, Object> incomingRow = rows.stream()
                .filter(row -> "IN".equals(row.get("direction")))
                .findFirst()
                .orElse(null);
        @SuppressWarnings("unchecked")
        Map<String, Object> outgoingRow = rows.stream()
                .filter(row -> "OUT".equals(row.get("direction")))
                .findFirst()
                .orElse(null);

        assertThat(incomingRow, notNullValue());
        assertThat(incomingRow.get("documentNumber"), is(invoiceNumber));
        assertThat(incomingRow.get("paymentMethod"), is("CASH"));
        assertThat(((Number) incomingRow.get("amount")).intValue(), is(12));

        assertThat(outgoingRow, notNullValue());
        assertThat(outgoingRow.get("documentNumber"), is("PINOUT-INV-1"));
        assertThat(outgoingRow.get("paymentMethod"), is("ABA"));
        assertThat(((Number) outgoingRow.get("amount")).intValue(), is(8));
    }

    @Test
    @WithMockUser(authorities = "PERM_REPORTS_VIEW")
    void expenseReportEndpoint_returnsExpenseRowsAndCategoryTotals() throws Exception {
        LocalDate today = LocalDate.now();
        ExpenseCategory office = createExpenseCategory("Office Supplies", "សម្ភារៈការិយាល័យ");
        ExpenseCategory logistics = createExpenseCategory("Delivery", "ដឹកជញ្ជូន");

        createExpense(today, office, "Printer paper", "APPROVED", "CASH", "EXP-REF-1", new BigDecimal("15.00"));
        createExpense(today.minusDays(1), logistics, "Bike fuel", "DRAFT", "ABA", "EXP-REF-2", new BigDecimal("9.50"));

        mockMvc.perform(get("/api/reports/expense")
                        .param("from", today.minusDays(1).toString())
                        .param("to", today.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fromDate").value(today.minusDays(1).toString()))
                .andExpect(jsonPath("$.toDate").value(today.toString()))
                .andExpect(jsonPath("$.rows.length()", is(2)))
                .andExpect(jsonPath("$.categories").isArray())
                .andExpect(jsonPath("$.methods").isArray())
                .andExpect(jsonPath("$.totals.totalAmount").value(24.5))
                .andExpect(jsonPath("$.totals.approvedAmount").value(15))
                .andExpect(jsonPath("$.totals.draftAmount").value(9.5))
                .andExpect(jsonPath("$.totals.approvedCount").value(1))
                .andExpect(jsonPath("$.totals.draftCount").value(1))
                .andExpect(jsonPath("$.totals.totalCount").value(2))
                .andExpect(jsonPath("$.totals.categories").value(2))
                .andExpect(jsonPath("$.byCategory.length()", is(2)));
    }

    private Supplier createSupplier() {
        Supplier supplier = new Supplier();
        supplier.setName("Report Supplier");
        supplier.setEmail("report-supplier@example.com");
        supplier.setDefaultCurrency("KHR");
        supplier.setActive(true);
        return supplierRepository.save(supplier);
    }

    private Store createStore(String name) {
        Store store = new Store();
        store.setName(name);
        store.setAddress("Phnom Penh");
        store.setPhone("+855000000");
        return storeRepository.save(store);
    }

    private Product createPurchasableTrackedProduct(String sku, String name) {
        Category category = new Category();
        category.setNameEn("Report Category");
        category.setNameKm("ប្រភេទរបាយការណ៍");
        category.setActive(true);
        category = categoryRepository.save(category);
        Unit each = unitRepository.findByCode("EACH").orElseThrow();

        Product product = new Product();
        product.setSku(sku);
        product.setBarcode(sku);
        product.setNameEn(name);
        product.setNameKm(name);
        product.setCost(new BigDecimal("8.00"));
        product.setPrice(new BigDecimal("12.00"));
        product.setActive(true);
        product.setSellable(true);
        product.setPurchasable(true);
        product.setTrackInventory(true);
        product.setProductType("INGREDIENT");
        product.setLowStockThreshold(new BigDecimal("1.00"));
        product.setCategory(category);
        product.setSaleUnit(each);
        product.setPurchaseUnit(each);
        product.setStockUnit(each);
        return productRepository.save(product);
    }

    private Product createSellableNonTrackedProduct(String sku, String name) {
        Category category = new Category();
        category.setNameEn("Report Sales Category");
        category.setNameKm("ប្រភេទលក់របាយការណ៍");
        category.setActive(true);
        category = categoryRepository.save(category);
        Unit each = unitRepository.findByCode("EACH").orElseThrow();

        Product product = new Product();
        product.setSku(sku);
        product.setBarcode(sku);
        product.setNameEn(name);
        product.setNameKm(name);
        product.setCost(new BigDecimal("6.00"));
        product.setPrice(new BigDecimal("12.00"));
        product.setActive(true);
        product.setSellable(true);
        product.setPurchasable(false);
        product.setTrackInventory(false);
        product.setProductType("FINISHED_GOOD");
        product.setCategory(category);
        product.setSaleUnit(each);
        product.setPurchaseUnit(each);
        product.setStockUnit(each);
        return productRepository.save(product);
    }

    private ExpenseCategory createExpenseCategory(String nameEn, String nameKm) {
        ExpenseCategory category = new ExpenseCategory();
        category.setNameEn(nameEn);
        category.setNameKm(nameKm);
        category.setColor("#10b981");
        category.setActive(true);
        return expenseCategoryRepository.save(category);
    }

    private Expense createExpense(LocalDate date, ExpenseCategory category, String description, String status, String paymentMethod,
            String reference, BigDecimal amount) {
        Expense expense = new Expense();
        expense.setExpenseDate(date);
        expense.setCategory(category);
        expense.setDescription(description);
        expense.setStatus(status);
        expense.setPaymentMethod(paymentMethod);
        expense.setReference(reference);
        expense.setAmount(amount);
        expense.setExpenseNumber("EXP-" + System.nanoTime());
        expense.setActive(true);
        return expenseRepository.save(expense);
    }
}
