package com.kaknnea.pos.controller;

import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.LocalDate;

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
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.StockItem;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.domain.Supplier;
import com.kaknnea.pos.domain.Unit;
import com.kaknnea.pos.repository.CategoryRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.SupplierInvoiceRepository;
import com.kaknnea.pos.repository.SupplierRepository;
import com.kaknnea.pos.repository.UnitRepository;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class PurchasingWorkflowIntegrationTest {

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
    private StockItemRepository stockItemRepository;

    @Autowired
    private SupplierInvoiceRepository supplierInvoiceRepository;

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_PURCHASE_MANAGE")
    void purchasingDocuments_followCanonicalPoToReturnFlow() throws Exception {
        Supplier supplier = createSupplier();
        Store store = createStore("Integration Main");
        Product product = createPurchasableTrackedProduct("PUR-INT-" + System.nanoTime(), "Workflow Beans");

        String poResponse = mockMvc.perform(post("/api/purchase-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "storeId": %d,
                                  "orderDeadline": "%s",
                                  "expectedArrival": "%s",
                                  "taxRate": 10,
                                  "notes": "Integration PO",
                                  "lines": [
                                    { "productId": %d, "quantity": 12, "unitCost": 5 }
                                  ]
                                }
                """.formatted(supplier.getId(), store.getId(), LocalDate.now().plusDays(3), LocalDate.now().plusDays(6), product.getId())))
        .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("SUBMITTED")))
                .andExpect(jsonPath("$.orderDeadline", is(LocalDate.now().plusDays(3).toString())))
                .andExpect(jsonPath("$.expectedArrival", is(LocalDate.now().plusDays(6).toString())))
                .andReturn()
                .getResponse()
                .getContentAsString();

        long purchaseOrderId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.id")).longValue();
        long purchaseOrderLineId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.lines[0].id")).longValue();

        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/submit"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("SUBMITTED")));

        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/approve"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("APPROVED")));

        String grnResponse = mockMvc.perform(post("/api/goods-receipts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "purchaseOrderId": %d,
                                  "storeId": %d,
                                  "notes": "Partial receipt",
                                  "lines": [
                                    { "purchaseOrderLineId": %d, "productId": %d, "quantity": 5, "unitCost": 5 }
                                  ]
                                }
                                """.formatted(purchaseOrderId, store.getId(), purchaseOrderLineId, product.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("POSTED")))
                .andReturn()
                .getResponse()
                .getContentAsString();

        long goodsReceiptId = ((Number) com.jayway.jsonpath.JsonPath.read(grnResponse, "$.id")).longValue();

        mockMvc.perform(get("/api/purchase-orders"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status", is("PARTIALLY_RECEIVED")))
                .andExpect(jsonPath("$[0].lines[0].receivedQuantity", is(5)));

        StockItem stockItem = stockItemRepository.findByProductIdAndStoreId(product.getId(), store.getId()).orElseThrow();
        org.junit.jupiter.api.Assertions.assertEquals(0, stockItem.getQuantity().compareTo(new BigDecimal("5")));

        String invoiceResponse = mockMvc.perform(post("/api/supplier-invoices")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "purchaseOrderId": %d,
                                  "goodsReceiptId": %d,
                                  "invoiceNumber": "INV-WF-1",
                                  "invoiceDate": "%s",
                                  "taxAmount": 2.50,
                                  "lines": [
                                    { "productId": %d, "quantity": 5, "unitCost": 5 }
                                  ]
                                }
                                """.formatted(supplier.getId(), purchaseOrderId, goodsReceiptId, LocalDate.now(), product.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.outstandingAmount", is(27.50)))
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
                                  "reference": "PAY-001",
                                  "notes": "Part payment"
                                }
                                """.formatted(invoiceId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount", is(10)));

        mockMvc.perform(get("/api/supplier-invoices"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status", is("PARTIAL")))
                .andExpect(jsonPath("$[0].outstandingAmount", is(17.50)));

        mockMvc.perform(post("/api/purchase-returns")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "goodsReceiptId": %d,
                                  "supplierInvoiceId": %d,
                                  "storeId": %d,
                                  "returnDate": "%s",
                                  "notes": "Damaged bags",
                                  "lines": [
                                    { "productId": %d, "quantity": 2, "unitCost": 5 }
                                  ]
                                }
                                """.formatted(supplier.getId(), goodsReceiptId, invoiceId, store.getId(), LocalDate.now(), product.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalAmount", is(10)));

        stockItem = stockItemRepository.findByProductIdAndStoreId(product.getId(), store.getId()).orElseThrow();
        org.junit.jupiter.api.Assertions.assertEquals(0, stockItem.getQuantity().compareTo(new BigDecimal("3")));
        org.junit.jupiter.api.Assertions.assertEquals(0,
                supplierInvoiceRepository.findById(invoiceId).orElseThrow().getOutstandingAmount().compareTo(new BigDecimal("7.50")));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_PURCHASE_MANAGE")
    void legacyPurchaseApi_staysAvailableButMarkedDeprecated() throws Exception {
        mockMvc.perform(get("/api/purchases"))
                .andExpect(status().isOk())
                .andExpect(header().string("Deprecation", "true"))
                .andExpect(header().string("Link", "</api/purchase-orders>; rel=\"successor-version\""));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_PURCHASE_MANAGE")
    void goodsReceipt_requiresApprovedPurchaseOrder() throws Exception {
        Supplier supplier = createSupplier();
        Store store = createStore("Receipt Rule Store");
        Product product = createPurchasableTrackedProduct("PUR-RULE-" + System.nanoTime(), "Receipt Rule Beans");

        String poResponse = mockMvc.perform(post("/api/purchase-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "storeId": %d,
                                  "taxRate": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 3, "unitCost": 4 }
                                  ]
                                }
                                """.formatted(supplier.getId(), store.getId(), product.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long purchaseOrderId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.id")).longValue();
        long purchaseOrderLineId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.lines[0].id")).longValue();

        mockMvc.perform(post("/api/goods-receipts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "purchaseOrderId": %d,
                                  "storeId": %d,
                                  "lines": [
                                    { "purchaseOrderLineId": %d, "productId": %d, "quantity": 1, "unitCost": 4 }
                                  ]
                                }
                                """.formatted(purchaseOrderId, store.getId(), purchaseOrderLineId, product.getId())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Only approved purchase orders can be received")));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_PURCHASE_MANAGE")
    void supplierPayment_cannotExceedRemainingBalance() throws Exception {
        Supplier supplier = createSupplier();
        Store store = createStore("Payment Rule Store");
        Product product = createPurchasableTrackedProduct("PUR-PAY-" + System.nanoTime(), "Payment Rule Beans");

        String poResponse = mockMvc.perform(post("/api/purchase-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "storeId": %d,
                                  "taxRate": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 2, "unitCost": 5 }
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
                                    { "purchaseOrderLineId": %d, "productId": %d, "quantity": 2, "unitCost": 5 }
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
                                  "invoiceNumber": "INV-OVERPAY-1",
                                  "invoiceDate": "%s",
                                  "taxAmount": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 2, "unitCost": 5 }
                                  ]
                                }
                                """.formatted(supplier.getId(), purchaseOrderId, goodsReceiptId, LocalDate.now(), product.getId())))
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
                                  "amount": 20,
                                  "reference": "OVERPAY-001"
                                }
                                """.formatted(invoiceId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Payment amount cannot exceed the remaining balance")));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_PURCHASE_MANAGE")
    void purchaseOrder_sendMarksSentAt() throws Exception {
        Supplier supplier = createSupplier();
        Store store = createStore("Send Rule Store");
        Product product = createPurchasableTrackedProduct("PUR-SEND-" + System.nanoTime(), "Send Rule Beans");

        String poResponse = mockMvc.perform(post("/api/purchase-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "storeId": %d,
                                  "orderDeadline": "%s",
                                  "expectedArrival": "%s",
                                  "taxRate": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 2, "unitCost": 5 }
                                  ]
                                }
                                """.formatted(supplier.getId(), store.getId(), LocalDate.now().plusDays(1), LocalDate.now().plusDays(2), product.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long purchaseOrderId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.id")).longValue();

        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/submit"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/send"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sentAt").isNotEmpty());
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_PURCHASE_MANAGE")
    void zeroTotalSupplierBill_isPaidWhenSaved() throws Exception {
        Supplier supplier = createSupplier();
        Store store = createStore("Zero Bill Store");
        Product product = createPurchasableTrackedProduct("PUR-ZERO-" + System.nanoTime(), "Zero Cost Beans");

        mockMvc.perform(post("/api/supplier-invoices")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "storeId": %d,
                                  "invoiceNumber": "INV-ZERO-1",
                                  "invoiceDate": "%s",
                                  "taxAmount": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 2, "unitCost": 0 }
                                  ]
                                }
                                """.formatted(supplier.getId(), store.getId(), LocalDate.now(), product.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("PAID")))
                .andExpect(jsonPath("$.totalAmount", is(0)))
                .andExpect(jsonPath("$.paidAmount", is(0)))
                .andExpect(jsonPath("$.outstandingAmount", is(0)));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_PURCHASE_MANAGE")
    void directSupplierBill_receivesStockImmediatelyWithoutGrn() throws Exception {
        Supplier supplier = createSupplier();
        Store store = createStore("Direct Bill Store");
        Product product = createPurchasableTrackedProduct("PUR-BILL-" + System.nanoTime(), "Direct Bill Beans");

        String poResponse = mockMvc.perform(post("/api/purchase-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "storeId": %d,
                                  "taxRate": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 4, "unitCost": 6 }
                                  ]
                                }
                                """.formatted(supplier.getId(), store.getId(), product.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long purchaseOrderId = ((Number) com.jayway.jsonpath.JsonPath.read(poResponse, "$.id")).longValue();

        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/submit"))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/purchase-orders/" + purchaseOrderId + "/approve"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/supplier-invoices")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "supplierId": %d,
                                  "purchaseOrderId": %d,
                                  "storeId": %d,
                                  "invoiceNumber": "INV-DIRECT-1",
                                  "invoiceDate": "%s",
                                  "taxAmount": 0,
                                  "lines": [
                                    { "productId": %d, "quantity": 4, "unitCost": 6 }
                                  ]
                                }
                                """.formatted(supplier.getId(), purchaseOrderId, store.getId(), LocalDate.now(), product.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.goodsReceiptId").isEmpty())
                .andExpect(jsonPath("$.storeId", is(store.getId().intValue())))
                .andExpect(jsonPath("$.stockApplied", is(true)))
                .andExpect(jsonPath("$.status", is("OPEN")));

        StockItem stockItem = stockItemRepository.findByProductIdAndStoreId(product.getId(), store.getId()).orElseThrow();
        org.junit.jupiter.api.Assertions.assertEquals(0, stockItem.getQuantity().compareTo(new BigDecimal("4")));

        mockMvc.perform(get("/api/purchase-orders"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status", is("RECEIVED")))
                .andExpect(jsonPath("$[0].lines[0].receivedQuantity", is(4)));
    }

    private Supplier createSupplier() {
        Supplier supplier = new Supplier();
        supplier.setName("Integration Supplier");
        supplier.setEmail("supplier@example.com");
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
        category.setNameEn("Integration Stock");
        category.setNameKm("ស្តុកសាកល្បង");
        category.setActive(true);
        category = categoryRepository.save(category);
        Unit each = unitRepository.findByCode("EACH").orElseThrow();
        Product product = new Product();
        product.setSku(sku);
        product.setBarcode(sku);
        product.setNameEn(name);
        product.setNameKm(name);
        product.setCost(new BigDecimal("4.00"));
        product.setPrice(new BigDecimal("9.00"));
        product.setActive(true);
        product.setSellable(false);
        product.setPurchasable(true);
        product.setTrackInventory(true);
        product.setProductType("INGREDIENT");
        product.setLowStockThreshold(new BigDecimal("2.00"));
        product.setCategory(category);
        product.setSaleUnit(each);
        product.setPurchaseUnit(each);
        product.setStockUnit(each);
        return productRepository.save(product);
    }
}
