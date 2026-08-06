package com.kaknnea.pos.api;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.repository.CustomerRepository;
import java.math.BigDecimal;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import org.springframework.security.test.context.support.WithMockUser;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(locations = "classpath:application-test.properties")
public class CustomerApiTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CustomerRepository customerRepository;

    @Test
    @WithMockUser(roles = "ACCOUNTANT")
    void testGetCustomerProfile() throws Exception {
        Customer customer = new Customer();
        customer.setCustomerCode("API-CUST-" + System.nanoTime());
        customer.setNameEn("API Customer");
        customer.setNameKm("អតិថិជន API");
        customer.setPhone("012345678");
        customer.setType("INDIVIDUAL");
        customer.setStatus("ACTIVE");
        customer.setCreditLimit(BigDecimal.ZERO);
        customer.setCreditBalance(BigDecimal.ZERO);
        customer = customerRepository.save(customer);

        mockMvc.perform(get("/api/customers/" + customer.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nameEn").exists())
                .andExpect(jsonPath("$.nameKm").exists());
    }
}
