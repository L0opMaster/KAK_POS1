package com.kaknnea.pos.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.Sale;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.repository.CategoryRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class ShiftCashEventIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private SaleRepository saleRepository;

    @Autowired
    private StockItemRepository stockItemRepository;

    private Product product;

    @BeforeEach
    void setUp() {
        User actor = userRepository.findByEmail("owner@kaknnea.local").orElseGet(() -> {
            User u = new User();
            u.setEmail("owner@kaknnea.local");
            u.setPasswordHash("test-hash");
            u.setFullName("Owner Test");
            u.setActive(true);
            return userRepository.save(u);
        });

        Category category = new Category();
        category.setNameEn("Cash Event Category");
        category.setNameKm("Cash Event Category");
        category.setActive(true);
        category = categoryRepository.save(category);

        String suffix = UUID.randomUUID().toString().substring(0, 8);
        Product p = new Product();
        p.setSku("CASH-EVT-" + suffix);
        p.setBarcode("BAR-CASH-EVT-" + suffix);
        p.setNameEn("Cash Event Product");
        p.setNameKm("Cash Event Product");
        p.setPrice(new BigDecimal("10.00"));
        p.setCost(new BigDecimal("4.00"));
        p.setActive(true);
        p.setTrackInventory(false);
        p.setCategory(category);
        product = productRepository.save(p);
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_SHIFT_MANAGE", "PERM_POS_SALE", "PERM_POS_REFUND"
    })
    void cashEvents_areRecordedForManualAndSaleFlows() throws Exception {
        // Open shift.
        MvcResult openShiftResult = mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"openingCash\":200.00}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").exists())
                .andReturn();

        Long shiftId = asLong(openShiftResult.getResponse().getContentAsString(), "id");

        // Manual drawer event.
        mockMvc.perform(post("/api/shifts/" + shiftId + "/cash-events")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"OPEN_DRAWER\",\"amount\":0.00,\"reason\":\"Manual open\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.type").value("OPEN_DRAWER"));

        // Create sale.
        String createSaleJson = """
                {
                  "taxRate": 0.10,
                  "invoiceDiscount": 0.00,
                  "clientRef": "cash-event-test-1",
                  "lines": [
                    {
                      "productId": %d,
                      "quantity": 1,
                      "unitPrice": 10.00,
                      "lineDiscount": 0.00
                    }
                  ]
                }
                """.formatted(product.getId());

        MvcResult createSaleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createSaleJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").exists())
                .andReturn();

        Long saleId = asLong(createSaleResult.getResponse().getContentAsString(), "id");
        Long saleLineId = asNestedLong(createSaleResult.getResponse().getContentAsString(), "lines", 0, "id");

        // Pay sale with CASH, should produce SALE_CASH.
        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"CASH\",\"amount\":11.00}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PAID"));

        // Refund part with CASH, should produce REFUND_CASH.
        mockMvc.perform(post("/api/pos/sales/" + saleId + "/refund")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "method": "CASH",
                                  "reason": "Test refund",
                                  "lines": [
                                    {
                                      "saleLineId": %d,
                                      "quantity": 0.5
                                    }
                                  ]
                                }
                                """.formatted(saleLineId)))
                .andExpect(status().isOk());

        // Verify shift cash events include expected types.
        mockMvc.perform(get("/api/shifts/" + shiftId + "/cash-events"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].type", hasItem("OPEN_SHIFT")))
                .andExpect(jsonPath("$[*].type", hasItem("OPEN_DRAWER")))
                .andExpect(jsonPath("$[*].type", hasItem("SALE_CASH")))
                .andExpect(jsonPath("$[*].type", hasItem("REFUND_CASH")));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_SHIFT_MANAGE", "PERM_POS_SALE"
    })
    void salesList_supportsStatusShiftDateAndQueryFilters() throws Exception {
        MvcResult openShiftResult = mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"openingCash\":100.00}"))
                .andExpect(status().isOk())
                .andReturn();

        Long shiftId = asLong(openShiftResult.getResponse().getContentAsString(), "id");

        String createSaleJson = """
                {
                  "taxRate": 0.10,
                  "invoiceDiscount": 0.00,
                  "clientRef": "%s",
                  "lines": [
                    {
                      "productId": %d,
                      "quantity": 1,
                      "unitPrice": 10.00,
                      "lineDiscount": 0.00
                    }
                  ]
                }
                """;

        Long paidSaleId = asLong(mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createSaleJson.formatted("sales-filter-test-paid", product.getId())))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(), "id");

        Long openSaleId = asLong(mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createSaleJson.formatted("sales-filter-test-open", product.getId())))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(), "id");

        mockMvc.perform(post("/api/pos/sales/" + paidSaleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"CASH\",\"amount\":11.00}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PAID"));

        String from = Instant.now().minusSeconds(3600).toString();
        String to = Instant.now().plusSeconds(3600).toString();

        mockMvc.perform(get("/api/pos/sales")
                        .param("status", "PAID")
                        .param("shiftId", shiftId.toString())
                        .param("dateFrom", from)
                        .param("dateTo", to))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].status", hasItem("PAID")))
                .andExpect(jsonPath("$[*].id", hasItem(paidSaleId.intValue())))
                .andExpect(jsonPath("$[*].id", not(hasItem(openSaleId.intValue()))));

        mockMvc.perform(get("/api/pos/sales")
                        .param("query", paidSaleId.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].id", hasItem(paidSaleId.intValue())))
                .andExpect(jsonPath("$[*].id", not(hasItem(openSaleId.intValue()))));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_SHIFT_MANAGE", "PERM_POS_SALE"
    })
    void paidSale_cannotBeEditedAfterTenderStarts_andNonCashOverpayIsRejected() throws Exception {
        mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"openingCash\":50.00}"))
                .andExpect(status().isOk());

        String createSaleJson = """
                {
                  "taxRate": 0.00,
                  "invoiceDiscount": 0.00,
                  "clientRef": "sale-lock-test",
                  "lines": [
                    {
                      "productId": %d,
                      "quantity": 1,
                      "unitPrice": 10.00,
                      "lineDiscount": 0.00
                    }
                  ]
                }
                """.formatted(product.getId());

        Long saleId = asLong(mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createSaleJson))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(), "id");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"KHQR\",\"amount\":11.00}]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Non-cash payment cannot exceed the remaining balance"));

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"CASH\",\"amount\":5.00}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paidAmount").value(5.0));

        mockMvc.perform(put("/api/pos/sales/" + saleId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "taxRate": 0.00,
                                  "invoiceDiscount": 0.00,
                                  "clientRef": "sale-lock-test-update",
                                  "lines": [
                                    {
                                      "productId": %d,
                                      "quantity": 2,
                                      "unitPrice": 10.00,
                                      "lineDiscount": 0.00
                                    }
                                  ]
                                }
                                """.formatted(product.getId())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Sale cannot be edited after payment has started"));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_SHIFT_MANAGE", "PERM_POS_SALE", "PERM_POS_REFUND"
    })
    void receipt_containsShiftStoreAndTenderBreakdown() throws Exception {
        MvcResult openShiftResult = mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"openingCash\":80.00}"))
                .andExpect(status().isOk())
                .andReturn();

        Long shiftId = asLong(openShiftResult.getResponse().getContentAsString(), "id");

        Long saleId = asLong(mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "taxRate": 0.00,
                                  "invoiceDiscount": 0.00,
                                  "clientRef": "receipt-metadata-test",
                                  "lines": [
                                    {
                                      "productId": %d,
                                      "quantity": 1,
                                      "unitPrice": 10.00,
                                      "lineDiscount": 0.00
                                    }
                                  ]
                                }
                                """.formatted(product.getId())))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(), "id");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"CASH\",\"amount\":6.00},{\"method\":\"KHQR\",\"amount\":4.00}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PAID"));

        mockMvc.perform(get("/api/pos/sales/" + saleId + "/receipt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.shiftId").value(shiftId))
                .andExpect(jsonPath("$.cashierName").isNotEmpty())
                .andExpect(jsonPath("$.storeName").isNotEmpty())
                .andExpect(jsonPath("$.payments[?(@.method=='CASH')]").exists())
                .andExpect(jsonPath("$.payments[?(@.method=='KHQR')]").exists())
                .andExpect(jsonPath("$.changeAmount").value(0.0));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_SHIFT_MANAGE", "PERM_POS_SALE", "PERM_POS_REFUND"
    })
    void refundApproval_isRequiredForManualOrNonCashRefunds() throws Exception {
        mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"openingCash\":80.00}"))
                .andExpect(status().isOk());

        Long saleId = asLong(mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "taxRate": 0.00,
                                  "invoiceDiscount": 0.00,
                                  "clientRef": "refund-approval-test",
                                  "lines": [
                                    {
                                      "productId": %d,
                                      "quantity": 1,
                                      "unitPrice": 10.00,
                                      "lineDiscount": 0.00
                                    }
                                  ]
                                }
                                """.formatted(product.getId())))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(), "id");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"KHQR\",\"amount\":10.00}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PAID"));

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/refund")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":10.00,\"method\":\"KHQR\",\"reason\":\"Gateway reversal\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Manager email is required for this refund"));

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/refund")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "amount": 10.00,
                                  "method": "KHQR",
                                  "reason": "Gateway reversal",
                                  "managerEmail": "manager@kaknnea.local",
                                  "managerPassword": "Password123!",
                                  "approvalReason": "Approved test refund",
                                  "forceApproval": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("REFUNDED"));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_SHIFT_MANAGE", "PERM_POS_SALE", "PERM_POS_REFUND", "PERM_INVENTORY_MANAGE"
    })
    void draftAndPartialPayment_doNotDeductStock_untilSaleIsFinalized() throws Exception {
        mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"openingCash\":100.00}"))
                .andExpect(status().isOk());

        String stockSku = "INV-DRAFT-" + UUID.randomUUID().toString().substring(0, 8);
        Product inventoryProduct = new Product();
        inventoryProduct.setSku(stockSku);
        inventoryProduct.setBarcode("BAR-" + stockSku);
        inventoryProduct.setNameEn("Draft Guard Product");
        inventoryProduct.setNameKm("Draft Guard Product");
        inventoryProduct.setPrice(new BigDecimal("10.00"));
        inventoryProduct.setCost(new BigDecimal("4.00"));
        inventoryProduct.setActive(true);
        inventoryProduct.setTrackInventory(true);
        inventoryProduct.setCategory(product.getCategory());
        inventoryProduct = productRepository.save(inventoryProduct);

        mockMvc.perform(post("/api/inventory/stock-in")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "productId": %d,
                                  "quantity": 10.00,
                                  "reason": "Initial stock"
                                }
                                """.formatted(inventoryProduct.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.quantity").value(10.0));

        MvcResult createSaleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "taxRate": 0.00,
                                  "invoiceDiscount": 0.00,
                                  "clientRef": "draft-stock-guard",
                                  "lines": [
                                    {
                                      "productId": %d,
                                      "quantity": 4.00,
                                      "unitPrice": 10.00,
                                      "lineDiscount": 0.00
                                    }
                                  ]
                                }
                                """.formatted(inventoryProduct.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andReturn();

        Long saleId = asLong(createSaleResult.getResponse().getContentAsString(), "id");

        assertQuantity(inventoryProduct.getId(), "10.00");

        mockMvc.perform(put("/api/pos/sales/" + saleId + "/hold"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HOLD"));

        assertQuantity(inventoryProduct.getId(), "10.00");

        mockMvc.perform(put("/api/pos/sales/" + saleId + "/resume"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DRAFT"));

        assertQuantity(inventoryProduct.getId(), "10.00");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"CASH\",\"amount\":20.00}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DRAFT"));

        assertQuantity(inventoryProduct.getId(), "10.00");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"CASH\",\"amount\":20.00}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PAID"));

        assertQuantity(inventoryProduct.getId(), "6.00");
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_SHIFT_MANAGE", "PERM_POS_SALE", "PERM_POS_REFUND", "PERM_INVENTORY_MANAGE"
    })
    void stock_isDeductedOnPayment_andReturnedOnlyForExplicitRefundLines() throws Exception {
        mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"openingCash\":100.00}"))
                .andExpect(status().isOk());

        String stockSku = "INV-" + UUID.randomUUID().toString().substring(0, 8);
        Product inventoryProduct = new Product();
        inventoryProduct.setSku(stockSku);
        inventoryProduct.setBarcode("BAR-" + stockSku);
        inventoryProduct.setNameEn("Tracked Product");
        inventoryProduct.setNameKm("Tracked Product");
        inventoryProduct.setPrice(new BigDecimal("10.00"));
        inventoryProduct.setCost(new BigDecimal("4.00"));
        inventoryProduct.setActive(true);
        inventoryProduct.setTrackInventory(true);
        inventoryProduct.setCategory(product.getCategory());
        inventoryProduct = productRepository.save(inventoryProduct);

        mockMvc.perform(post("/api/inventory/stock-in")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "productId": %d,
                                  "quantity": 10.00,
                                  "reason": "Initial stock"
                                }
                                """.formatted(inventoryProduct.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.quantity").value(10.0));

        MvcResult createSaleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "taxRate": 0.00,
                                  "invoiceDiscount": 0.00,
                                  "clientRef": "stock-movement-test",
                                  "lines": [
                                    {
                                      "productId": %d,
                                      "quantity": 4.00,
                                      "unitPrice": 10.00,
                                      "lineDiscount": 0.00
                                    }
                                  ]
                                }
                                """.formatted(inventoryProduct.getId())))
                .andExpect(status().isOk())
                .andReturn();

        Long saleId = asLong(createSaleResult.getResponse().getContentAsString(), "id");
        Long saleLineId = asNestedLong(createSaleResult.getResponse().getContentAsString(), "lines", 0, "id");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"CASH\",\"amount\":40.00}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PAID"));

        assertQuantity(inventoryProduct.getId(), "6.00");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/refund")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "method": "CASH",
                                  "reason": "Customer returned one unit",
                                  "lines": [
                                    {
                                      "saleLineId": %d,
                                      "quantity": 1.00
                                    }
                                  ]
                                }
                                """.formatted(saleLineId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PARTIALLY_REFUNDED"));

        assertQuantity(inventoryProduct.getId(), "7.00");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/refund")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "amount": 5.00,
                                  "method": "CASH",
                                  "reason": "Price adjustment",
                                  "managerEmail": "manager@kaknnea.local",
                                  "managerPassword": "Password123!",
                                  "approvalReason": "Manual adjustment approved"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PARTIALLY_REFUNDED"));

        assertQuantity(inventoryProduct.getId(), "7.00");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/refund")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "method": "CASH",
                                  "reason": "Over refund attempt",
                                  "lines": [
                                    {
                                      "saleLineId": %d,
                                      "quantity": 4.00
                                    }
                                  ]
                                }
                                """.formatted(saleLineId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Refund quantity exceeds remaining sold quantity"));

        assertQuantity(inventoryProduct.getId(), "7.00");
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_SHIFT_MANAGE", "PERM_POS_SALE", "PERM_INVENTORY_MANAGE"
    })
    void confirmedInvoice_becomesCollectableCredit_andDeductsStockWithoutUsingHold() throws Exception {
        mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"openingCash\":100.00}"))
                .andExpect(status().isOk());

        String stockSku = "INV-" + UUID.randomUUID().toString().substring(0, 8);
        Product inventoryProduct = new Product();
        inventoryProduct.setSku(stockSku);
        inventoryProduct.setBarcode("BAR-" + stockSku);
        inventoryProduct.setNameEn("Invoice Confirm Product");
        inventoryProduct.setNameKm("Invoice Confirm Product");
        inventoryProduct.setPrice(new BigDecimal("10.00"));
        inventoryProduct.setCost(new BigDecimal("4.00"));
        inventoryProduct.setActive(true);
        inventoryProduct.setTrackInventory(true);
        inventoryProduct.setCategory(product.getCategory());
        inventoryProduct = productRepository.save(inventoryProduct);

        Customer customer = new Customer();
        customer.setCustomerCode("SO-CUST-" + UUID.randomUUID().toString().substring(0, 8));
        customer.setNameEn("Sales Order Customer");
        customer.setNameKm("Sales Order Customer");
        customer.setStatus("ACTIVE");
        customer.setType("RETAIL");
        customer.setCreditLimit(new BigDecimal("1000.00"));
        customer = customerRepository.save(customer);

        mockMvc.perform(post("/api/inventory/stock-in")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "productId": %d,
                                  "quantity": 10.00,
                                  "reason": "Initial stock"
                                }
                                """.formatted(inventoryProduct.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.quantity").value(10.0));

        MvcResult createSaleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "orderDate": "2026-04-08",
                                  "deliveryDate": "2026-04-09",
                                  "paymentTerms": "CASH",
                                  "taxRate": 0.00,
                                  "invoiceDiscount": 0.00,
                                  "deliveryCharge": 0.00,
                                  "otherCharge": 0.00,
                                  "depositAmount": 0.00,
                                  "clientRef": "invoice-confirm-test",
                                  "lines": [
                                    {
                                      "productId": %d,
                                      "quantity": 4.00,
                                      "unitPrice": 10.00,
                                      "lineDiscount": 0.00
                                    }
                                  ]
                                }
                                """.formatted(customer.getId(), inventoryProduct.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andReturn();

        Long saleId = asLong(createSaleResult.getResponse().getContentAsString(), "id");

        assertQuantity(inventoryProduct.getId(), "10.00");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/confirm"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CREDIT"))
                .andExpect(jsonPath("$.creditDueAt").exists());

        assertQuantity(inventoryProduct.getId(), "6.00");

        Sale confirmedSale = saleRepository.findById(saleId).orElseThrow();
        org.junit.jupiter.api.Assertions.assertEquals("CREDIT", confirmedSale.getStatus());
        org.junit.jupiter.api.Assertions.assertTrue(confirmedSale.isStockApplied());

        Customer refreshedCustomer = customerRepository.findById(customer.getId()).orElseThrow();
        org.junit.jupiter.api.Assertions.assertEquals(new BigDecimal("40.00"), refreshedCustomer.getCreditBalance());
    }

    private Long asLong(String json, String key) throws Exception {
        JsonNode root = objectMapper.readTree(json);
        return root.get(key).asLong();
    }

    private Long asNestedLong(String json, String arrayKey, int index, String key) throws Exception {
        JsonNode root = objectMapper.readTree(json);
        return root.get(arrayKey).get(index).get(key).asLong();
    }

    private void assertQuantity(Long productId, String expectedQuantity) {
        BigDecimal actual = stockItemRepository.findAllByProductId(productId).stream()
                .findFirst()
                .orElseThrow()
                .getQuantity();
        org.junit.jupiter.api.Assertions.assertEquals(new BigDecimal(expectedQuantity), actual);
    }
}
