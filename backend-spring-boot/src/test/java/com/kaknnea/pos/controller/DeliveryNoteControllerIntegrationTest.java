package com.kaknnea.pos.controller;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.repository.CategoryRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import java.math.BigDecimal;
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

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class DeliveryNoteControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private StockItemRepository stockItemRepository;

    private Customer customer;
    private Product product;

    @BeforeEach
    void setUp() {
        Category category = new Category();
        category.setNameEn("Delivery Test");
        category.setNameKm("ដឹកជញ្ជូន");
        category.setActive(true);
        category = categoryRepository.save(category);

        customer = new Customer();
        customer.setCustomerCode("DN-CUST-001");
        customer.setDisplayName("Delivery Customer");
        customer.setNameEn("Delivery Customer");
        customer.setNameKm("អតិថិជនដឹកជញ្ជូន");
        customer.setPhone("012345678");
        customer.setAddress("Phnom Penh");
        customer.setType("REGULAR");
        customer.setStatus("ACTIVE");
        customer.setCreditLimit(new BigDecimal("500.00"));
        customer.setCreditBalance(BigDecimal.ZERO);
        customer = customerRepository.save(customer);

        product = new Product();
        product.setNameEn("Delivery Product");
        product.setNameKm("ផលិតផលដឹក");
        product.setSku("DN-PROD-001");
        product.setBarcode("DN-BAR-001");
        product.setPrice(new BigDecimal("12.00"));
        product.setCost(new BigDecimal("5.00"));
        product.setActive(true);
        product.setTrackInventory(true);
        product.setCategory(category);
        product = productRepository.save(product);
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_POS_SALE", "PERM_INVENTORY_MANAGE"
    })
    void listCreateEditAndTransitionDeliveryNotes() throws Exception {
        mockMvc.perform(post("/api/inventory/stock-in")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "productId": %d,
                                  "quantity": 10.00,
                                  "reason": "Delivery note test stock"
                                }
                                """.formatted(product.getId())))
                .andExpect(status().isOk());

        String saleJson = createSalePayload("dn-flow-1");
        MvcResult saleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(saleJson))
                .andExpect(status().isOk())
                .andReturn();

        long saleId = asLong(saleResult, "$.id");
        long saleLineId = asLong(saleResult, "$.lines[0].id");

        String created = mockMvc.perform(post("/api/delivery-notes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(saleId, saleLineId, "2026-03-13", "2.00")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("DRAFT")))
                .andExpect(jsonPath("$.saleId", is((int) saleId)))
                .andExpect(jsonPath("$.lines[0].saleLineId", is((int) saleLineId)))
                .andReturn()
                .getResponse()
                .getContentAsString();

        long noteId = asLong(created, "$.id");

        mockMvc.perform(get("/api/delivery-notes"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThanOrEqualTo(1))))
                .andExpect(jsonPath("$[0].saleId").exists());

        mockMvc.perform(put("/api/delivery-notes/" + noteId + "/details")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(saleId, saleLineId, "2026-03-14", "1.00")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.deliveryDate", is("2026-03-14")))
                .andExpect(jsonPath("$.lines[0].quantity", is(1.0)));

        mockMvc.perform(put("/api/delivery-notes/" + noteId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"DISPATCHED\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("DISPATCHED")));

        mockMvc.perform(put("/api/delivery-notes/" + noteId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"DELIVERED\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("DELIVERED")));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_POS_SALE", "PERM_INVENTORY_MANAGE"
    })
    void rejectsIneligibleDuplicateAndInvalidTransitions() throws Exception {
        stockIn("10.00", "Delivery note validation stock");

        MvcResult voidSaleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createSalePayload("dn-void-1")))
                .andExpect(status().isOk())
                .andReturn();

        long voidSaleId = asLong(voidSaleResult, "$.id");
        long voidSaleLineId = asLong(voidSaleResult, "$.lines[0].id");

        mockMvc.perform(put("/api/pos/sales/" + voidSaleId + "/void")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"cancelled\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("VOID")));

        mockMvc.perform(post("/api/delivery-notes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(voidSaleId, voidSaleLineId, "2026-03-13", "1.00")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Sale is not eligible for delivery note creation")));

        MvcResult eligibleSaleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createSalePayload("dn-active-1")))
                .andExpect(status().isOk())
                .andReturn();

        long eligibleSaleId = asLong(eligibleSaleResult, "$.id");
        long eligibleSaleLineId = asLong(eligibleSaleResult, "$.lines[0].id");

        String noteResponse = mockMvc.perform(post("/api/delivery-notes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(eligibleSaleId, eligibleSaleLineId, "2026-03-13", "1.00")))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long noteId = asLong(noteResponse, "$.id");

        mockMvc.perform(post("/api/delivery-notes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(eligibleSaleId, eligibleSaleLineId, "2026-03-13", "1.00")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("This sale already has an active delivery note")));

        mockMvc.perform(put("/api/delivery-notes/" + noteId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"DELIVERED\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Draft delivery notes can only be dispatched or cancelled")));

        mockMvc.perform(put("/api/delivery-notes/" + noteId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"DISPATCHED\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/delivery-notes/" + noteId + "/details")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(eligibleSaleId, eligibleSaleLineId, "2026-03-14", "1.00")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Only draft delivery notes can be edited")));

        mockMvc.perform(put("/api/delivery-notes/" + noteId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"CANCELLED\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("CANCELLED")));

        mockMvc.perform(put("/api/delivery-notes/" + noteId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"DISPATCHED\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Delivery note is already finalized")));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_POS_SALE", "PERM_INVENTORY_MANAGE"
    })
    void rejectsMismatchedSaleAndInvalidQuantity() throws Exception {
        stockIn("10.00", "Delivery note mismatch stock");

        MvcResult firstSaleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createSalePayload("dn-mismatch-1")))
                .andExpect(status().isOk())
                .andReturn();

        MvcResult secondSaleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createSalePayload("dn-mismatch-2")))
                .andExpect(status().isOk())
                .andReturn();

        long firstSaleId = asLong(firstSaleResult, "$.id");
        long firstSaleLineId = asLong(firstSaleResult, "$.lines[0].id");
        long secondSaleId = asLong(secondSaleResult, "$.id");
        long secondSaleLineId = asLong(secondSaleResult, "$.lines[0].id");

        String noteResponse = mockMvc.perform(post("/api/delivery-notes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(firstSaleId, firstSaleLineId, "2026-03-13", "1.00")))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long noteId = asLong(noteResponse, "$.id");

        mockMvc.perform(put("/api/delivery-notes/" + noteId + "/details")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(secondSaleId, secondSaleLineId, "2026-03-13", "1.00")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Delivery note sale cannot be changed")));

        mockMvc.perform(post("/api/delivery-notes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(secondSaleId, secondSaleLineId, "2026-03-13", "99.00")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Invalid delivery quantity for Delivery Product")));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "PERM_POS_SALE", "PERM_SHIFT_MANAGE", "PERM_INVENTORY_MANAGE"
    })
    void deliveredNote_deductsStock_andLaterPaymentOnlyDeductsRemainingQuantity() throws Exception {
        mockMvc.perform(post("/api/shifts/open")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"openingCash\":100.00}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/inventory/stock-in")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "productId": %d,
                                  "quantity": 10.00,
                                  "reason": "Delivery flow stock"
                                }
                                """.formatted(product.getId())))
                .andExpect(status().isOk());

        MvcResult saleResult = mockMvc.perform(post("/api/pos/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createSalePayload("dn-stock-deduct-1")))
                .andExpect(status().isOk())
                .andReturn();

        long saleId = asLong(saleResult, "$.id");
        long saleLineId = asLong(saleResult, "$.lines[0].id");

        String created = mockMvc.perform(post("/api/delivery-notes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(deliveryNotePayload(saleId, saleLineId, "2026-03-13", "1.00")))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long noteId = asLong(created, "$.id");

        mockMvc.perform(put("/api/delivery-notes/" + noteId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"DISPATCHED\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/delivery-notes/" + noteId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"DELIVERED\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("DELIVERED")));

        assertQuantity("9.00");

        mockMvc.perform(post("/api/pos/sales/" + saleId + "/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"payments\":[{\"method\":\"CASH\",\"amount\":26.40}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("PAID")));

        assertQuantity("8.00");
    }

    private String createSalePayload(String clientRef) {
        return """
                {
                  "customerId": %d,
                  "taxRate": 0.10,
                  "invoiceDiscount": 0.00,
                  "clientRef": "%s",
                  "lines": [
                    {
                      "productId": %d,
                      "quantity": 2,
                      "unitPrice": 12.00,
                      "lineDiscount": 0.00
                    }
                  ]
                }
                """.formatted(customer.getId(), clientRef, product.getId());
    }

    private String deliveryNotePayload(long saleId, long saleLineId, String deliveryDate, String quantity) {
        return """
                {
                  "saleId": %d,
                  "deliveryDate": "%s",
                  "contactName": "Dara Dispatcher",
                  "contactPhone": "099888777",
                  "deliveryAddress": "Street 51, Phnom Penh",
                  "notes": "Handle with care",
                  "lines": [
                    {
                      "saleLineId": %d,
                      "quantity": %s
                    }
                  ]
                }
                """.formatted(saleId, deliveryDate, saleLineId, quantity);
    }

    private void stockIn(String quantity, String reason) throws Exception {
        mockMvc.perform(post("/api/inventory/stock-in")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "productId": %d,
                                  "quantity": %s,
                                  "reason": "%s"
                                }
                                """.formatted(product.getId(), quantity, reason)))
                .andExpect(status().isOk());
    }

    private long asLong(MvcResult result, String jsonPath) throws Exception {
        Number value = JsonPath.read(result.getResponse().getContentAsString(), jsonPath);
        return value.longValue();
    }

    private long asLong(String json, String jsonPath) {
        Number value = JsonPath.read(json, jsonPath);
        return value.longValue();
    }

    private void assertQuantity(String expectedQuantity) {
        BigDecimal actual = stockItemRepository.findAllByProductId(product.getId()).stream()
                .findFirst()
                .orElseThrow()
                .getQuantity();
        org.junit.jupiter.api.Assertions.assertEquals(new BigDecimal(expectedQuantity), actual);
    }
}
