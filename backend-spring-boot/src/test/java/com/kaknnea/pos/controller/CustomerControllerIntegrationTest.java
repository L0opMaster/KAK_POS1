package com.kaknnea.pos.controller;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class CustomerControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithMockUser(authorities = "PERM_CUSTOMER_MANAGE")
    void createUpdateListAndSearchCustomers_workWithExpandedFields() throws Exception {
        String created = mockMvc.perform(post("/api/customers")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "BIZ001",
                                  "type": "BUSINESS",
                                  "displayName": "Dara Coffee Shop",
                                  "nameEn": "Dara Coffee Shop",
                                  "phone": "+85512345678",
                                  "email": "dara@coffee.com",
                                  "address": "Phnom Penh",
                                  "notes": "Priority customer",
                                  "status": "ACTIVE",
                                  "contactPerson": "Dara",
                                  "paymentTerms": "Net 30",
                                  "taxNumber": "TAX-100",
                                  "creditLimit": 1000
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code", is("BIZ001")))
                .andExpect(jsonPath("$.displayName", is("Dara Coffee Shop")))
                .andExpect(jsonPath("$.email", is("dara@coffee.com")))
                .andExpect(jsonPath("$.status", is("ACTIVE")))
                .andReturn()
                .getResponse()
                .getContentAsString();

        Number customerIdValue = com.jayway.jsonpath.JsonPath.read(created, "$.id");
        long customerId = customerIdValue.longValue();

        mockMvc.perform(put("/api/customers/" + customerId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "BIZ001",
                                  "type": "BUSINESS",
                                  "displayName": "Dara Coffee HQ",
                                  "nameEn": "Dara Coffee HQ",
                                  "nameKm": "ដារ៉ា",
                                  "phone": "+85512345678",
                                  "email": "hq@coffee.com",
                                  "address": "Phnom Penh",
                                  "notes": "VIP",
                                  "status": "INACTIVE",
                                  "contactPerson": "Sokha",
                                  "paymentTerms": "Net 15",
                                  "taxNumber": "TAX-200",
                                  "creditLimit": 1500
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.displayName", is("Dara Coffee HQ")))
                .andExpect(jsonPath("$.status", is("INACTIVE")))
                .andExpect(jsonPath("$.paymentTerms", is("Net 15")));

        mockMvc.perform(get("/api/customers"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThanOrEqualTo(1))))
                .andExpect(jsonPath("$[?(@.code == 'BIZ001')].email").exists());

        mockMvc.perform(get("/api/customers/search?q=BIZ001&status=INACTIVE&page=0&size=10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(greaterThanOrEqualTo(1))))
                .andExpect(jsonPath("$.data[0].code", is("BIZ001")))
                .andExpect(jsonPath("$.data[0].status", is("INACTIVE")))
                .andExpect(jsonPath("$.total", is(1)));
    }
}
