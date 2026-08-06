package com.kaknnea.pos.controller;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.repository.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class EstimateWorkflowIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private CustomerRepository customerRepository;
    @Autowired private ProductRepository productRepository;
    @Autowired private CategoryRepository categoryRepository;
    @Autowired private StoreRepository storeRepository;
    @Autowired private StockItemRepository stockItemRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private ShiftRepository shiftRepository;

    private Long customerId;
    private Long productId;

    @BeforeEach
    void setUp() throws Exception {
        if (customerId != null) return;
        Customer c = new Customer();
        c.setDisplayName("Test Corp");
        c.setNameEn("Test Corp EN");
        c.setNameKm("Test Corp KM");
        c.setCustomerCode("EST-" + System.nanoTime());
        c.setStatus("ACTIVE");
        c.setCreditBalance(BigDecimal.ZERO);
        c.setCreditLimit(BigDecimal.valueOf(10000));
        customerId = customerRepository.save(c).getId();

        String sku = "EST-" + System.nanoTime();
        Category cat = new Category();
        cat.setNameEn("Cat");
        cat.setNameKm("Cat");
        cat.setActive(true);
        cat = categoryRepository.save(cat);

        Product p = new Product();
        p.setNameEn("P");
        p.setNameKm("P");
        p.setSku(sku);
        p.setBarcode(sku);
        p.setCategory(cat);
        p.setPrice(BigDecimal.valueOf(100));
        p.setCost(BigDecimal.valueOf(50));
        productId = productRepository.save(p).getId();

        Store s = new Store();
        s.setName("Main");
        s = storeRepository.save(s);

        StockItem si = new StockItem();
        si.setProduct(p);
        si.setStore(s);
        si.setQuantity(BigDecimal.valueOf(999));
        si.setLowStockThreshold(BigDecimal.valueOf(5));
        stockItemRepository.save(si);

        // Open a shift via API (handles all required fields)
        mockMvc.perform(post("/api/shifts/open")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"storeId\":%d,\"openingCash\":1000}".formatted(s.getId())))
            .andExpect(status().isOk());
    }

    @Test @Order(1)
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_POS_SALE")
    void createEstimate() throws Exception {
        mockMvc.perform(post("/api/pos/sales/estimates")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"customerId":%d,"estimateExpiryDate":"%s",
                     "lines":[{"productId":%d,"quantity":2,"unitPrice":100}]}
                    """.formatted(customerId, LocalDate.now().plusDays(30), productId)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status", is("ESTIMATE")))
            .andExpect(jsonPath("$.isEstimate", is(true)))
            .andExpect(jsonPath("$.customerName", containsString("Test Corp")));
    }

    @Test @Order(2)
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_POS_SALE")
    void fullLifecycle() throws Exception {
        String r1 = mockMvc.perform(post("/api/pos/sales/estimates")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"customerId":%d,"estimateExpiryDate":"%s",
                     "lines":[{"productId":%d,"quantity":3,"unitPrice":75}]}
                    """.formatted(customerId, LocalDate.now().plusDays(30), productId)))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        Long eid = objectMapper.readTree(r1).get("id").asLong();

        mockMvc.perform(post("/api/pos/sales/{id}/send-estimate", eid))
            .andExpect(status().isOk());
        mockMvc.perform(post("/api/pos/sales/{id}/accept-estimate", eid))
            .andExpect(jsonPath("$.status", is("ESTIMATE_ACCEPTED")));

        String conv = mockMvc.perform(post("/api/pos/sales/{id}/convert-from-estimate", eid))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        Long sid = objectMapper.readTree(conv).get("id").asLong();

        var j = objectMapper.readTree(conv);
        mockMvc.perform(post("/api/pos/sales/{id}/pay", sid)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"payments\":[{\"method\":\"CASH\",\"amount\":%.2f}]}".formatted(j.get("grandTotal").asDouble())))
            .andExpect(jsonPath("$.status", is("PAID")));

        mockMvc.perform(get("/api/pos/sales/{id}", eid))
            .andExpect(jsonPath("$.status", is("ESTIMATE_CONVERTED")));
    }

    @Test @Order(3)
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_POS_SALE")
    void declineEstimate() throws Exception {
        String r = mockMvc.perform(post("/api/pos/sales/estimates")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"customerId":%d,"estimateExpiryDate":"%s",
                     "lines":[{"productId":%d,"quantity":1,"unitPrice":100}]}
                    """.formatted(customerId, LocalDate.now().plusDays(30), productId)))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        Long eid = objectMapper.readTree(r).get("id").asLong();

        mockMvc.perform(post("/api/pos/sales/{id}/send-estimate", eid));
        mockMvc.perform(post("/api/pos/sales/{id}/decline-estimate", eid)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"reason\":\"Budget rejected\"}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status", is("ESTIMATE_DECLINED")));
    }

    @Test @Order(4)
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_POS_SALE")
    void cannotConvertUnaccepted() throws Exception {
        String r = mockMvc.perform(post("/api/pos/sales/estimates")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"customerId":%d,"estimateExpiryDate":"%s",
                     "lines":[{"productId":%d,"quantity":1,"unitPrice":100}]}
                    """.formatted(customerId, LocalDate.now().plusDays(30), productId)))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        Long eid = objectMapper.readTree(r).get("id").asLong();
        mockMvc.perform(post("/api/pos/sales/{id}/send-estimate", eid));
        mockMvc.perform(post("/api/pos/sales/{id}/convert-from-estimate", eid))
            .andExpect(status().isBadRequest());
    }

    @Test @Order(5)
    @WithMockUser(username = "owner@kaknnea.local", authorities = "PERM_POS_SALE")
    void listEstimates() throws Exception {
        mockMvc.perform(get("/api/pos/sales/estimates"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$").isArray());
    }
}
