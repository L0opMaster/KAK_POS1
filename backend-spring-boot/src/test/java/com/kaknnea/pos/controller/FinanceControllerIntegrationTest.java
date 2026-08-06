package com.kaknnea.pos.controller;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class FinanceControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithMockUser(authorities = "PERM_PURCHASE_MANAGE")
    void payablesSummaryEndpoint_returnsSummaryShape() throws Exception {
        mockMvc.perform(get("/api/finance/ap-summary"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalOutstanding").exists())
                .andExpect(jsonPath("$.invoiceCount").exists())
                .andExpect(jsonPath("$.aging").isArray())
                .andExpect(jsonPath("$.aging.length()").value(greaterThanOrEqualTo(4)))
                .andExpect(jsonPath("$.invoices").isArray());
    }

    @Test
    @WithMockUser(authorities = "PERM_CUSTOMER_MANAGE")
    void receivablesSummaryEndpoint_returnsSummaryShape() throws Exception {
        mockMvc.perform(get("/api/finance/ar-summary"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalOutstanding").exists())
                .andExpect(jsonPath("$.totalCreditLimit").exists())
                .andExpect(jsonPath("$.invoiceCount").exists())
                .andExpect(jsonPath("$.aging").isArray())
                .andExpect(jsonPath("$.aging.length()").value(greaterThanOrEqualTo(4)))
                .andExpect(jsonPath("$.invoices").isArray());
    }
}
