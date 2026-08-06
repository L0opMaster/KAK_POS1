package com.kaknnea.pos.controller;

import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.notNullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.domain.CustomerCreditOpeningBalance;
import com.kaknnea.pos.domain.Payment;
import com.kaknnea.pos.repository.CustomerCreditOpeningBalanceRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.PaymentRepository;
import java.math.BigDecimal;
import java.util.Optional;
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
class CustomerCreditCollectionIntegrationTest {

  @Autowired
  private MockMvc mockMvc;

  @Autowired
  private CustomerRepository customerRepository;

  @Autowired
  private CustomerCreditOpeningBalanceRepository openingBalanceRepository;

  @Autowired
  private PaymentRepository paymentRepository;

  @Autowired
  private ObjectMapper objectMapper;

  private Customer customer;
  private CustomerCreditOpeningBalance openingBalance;

  @BeforeEach
  void setUp() {
    customer = new Customer();
    customer.setCustomerCode("CUST-CREDIT-T01");
    customer.setType("INDIVIDUAL");
    customer.setNameEn("Credit Test");
    customer.setNameKm("អតិថិជនឥណទាន");
    customer.setPhone("099123456");
    customer.setCreditLimit(new BigDecimal("500.00"));
    customer.setCreditBalance(new BigDecimal("60.00"));
    customer = customerRepository.save(customer);

    openingBalance = new CustomerCreditOpeningBalance();
    openingBalance.setCustomer(customer);
    openingBalance.setOriginalAmount(new BigDecimal("60.00"));
    openingBalance.setRemainingAmount(new BigDecimal("60.00"));
    openingBalance.setNote("Opening test debt");
    openingBalance = openingBalanceRepository.save(openingBalance);
  }

  @Test
  @WithMockUser(roles = "CASHIER")
  void previewCollection_returnsFifoOpeningAllocation() throws Exception {
    mockMvc.perform(post("/api/customers/" + customer.getId() + "/collections/preview")
        .contentType(MediaType.APPLICATION_JSON)
        .content("""
            {
              "amount": 30.00,
              "strategy": "FIFO"
            }
            """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.customerId", is(customer.getId().intValue())))
        .andExpect(jsonPath("$.valid", is(true)))
        .andExpect(jsonPath("$.amountRequested", is(30.00)))
        .andExpect(jsonPath("$.amountAllocatable", is(30.00)))
        .andExpect(jsonPath("$.allocations", hasSize(1)))
        .andExpect(jsonPath("$.allocations[0].targetType", is("OPENING_BALANCE")))
        .andExpect(jsonPath("$.allocations[0].openingBalanceId", is(openingBalance.getId().intValue())))
        .andExpect(jsonPath("$.allocations[0].allocatedAmount", is(30.00)));
  }

  @Test
  @WithMockUser(roles = "CASHIER")
  void collectCollection_withSameIdempotencyKey_returnsSamePayment() throws Exception {
    final String requestBody = """
        {
          "amount": 20.00,
          "paymentMethod": "CASH",
          "notes": "test collect",
          "strategy": "FIFO",
          "idempotencyKey": "K-100"
        }
        """;

    MvcResult first = mockMvc.perform(post("/api/customers/" + customer.getId() + "/collections")
        .contentType(MediaType.APPLICATION_JSON)
        .content(requestBody))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.paymentId", notNullValue()))
        .andExpect(jsonPath("$.referenceNumber", matchesPattern("PAY-\\d{5}")))
        .andExpect(jsonPath("$.amountCollected", is(20.00)))
        .andReturn();

    JsonNode firstJson = objectMapper.readTree(first.getResponse().getContentAsString());
    long firstPaymentId = firstJson.get("paymentId").asLong();

    MvcResult second = mockMvc.perform(post("/api/customers/" + customer.getId() + "/collections")
        .contentType(MediaType.APPLICATION_JSON)
        .content(requestBody))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.referenceNumber", matchesPattern("PAY-\\d{5}")))
        .andReturn();

    JsonNode secondJson = objectMapper.readTree(second.getResponse().getContentAsString());
    long secondPaymentId = secondJson.get("paymentId").asLong();
    assertEquals(firstPaymentId, secondPaymentId);

    Optional<Payment> payment = paymentRepository.findByReferenceNumber("COLLECT-" + customer.getId() + "-K-100");
    assertTrue(payment.isPresent());

    CustomerCreditOpeningBalance refreshedOpening = openingBalanceRepository.findById(openingBalance.getId())
        .orElseThrow();
    assertEquals(0, refreshedOpening.getRemainingAmount().compareTo(new BigDecimal("40.00")));
  }

  @Test
  @WithMockUser(roles = "CASHIER")
  void creditLedger_afterCollection_includesCollectionEntry() throws Exception {
    mockMvc.perform(post("/api/customers/" + customer.getId() + "/collections")
        .contentType(MediaType.APPLICATION_JSON)
        .content("""
            {
              "amount": 15.00,
              "paymentMethod": "CASH",
              "strategy": "FIFO",
              "idempotencyKey": "LEDGER-001"
            }
            """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.paymentId", notNullValue()));

    mockMvc.perform(get("/api/customers/" + customer.getId() + "/credit-ledger"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.customerId", is(customer.getId().intValue())))
        .andExpect(jsonPath("$.creditBalance", is(45.00)))
        .andExpect(jsonPath("$.entries", hasSize(org.hamcrest.Matchers.greaterThanOrEqualTo(1))))
        .andExpect(jsonPath("$.entries[0].entryType", notNullValue()))
        .andExpect(jsonPath("$.entries[0].targetType", notNullValue()));
  }

  @Test
  @WithMockUser(roles = "CASHIER")
  void collect_manualAllocations_appliesRequestedTargets() throws Exception {
    mockMvc.perform(post("/api/customers/" + customer.getId() + "/collections")
        .contentType(MediaType.APPLICATION_JSON)
        .content("""
            {
              "amount": 30.00,
              "paymentMethod": "CASH",
              "strategy": "MANUAL",
              "idempotencyKey": "MANUAL-001",
              "allocations": [
                {
                  "targetType": "OPENING_BALANCE",
                  "openingBalanceId": %d,
                  "allocatedAmount": 30.00
                }
              ]
            }
            """.formatted(openingBalance.getId())))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.referenceNumber", matchesPattern("PAY-\\d{5}")))
        .andExpect(jsonPath("$.amountCollected", is(30.00)))
        .andExpect(jsonPath("$.allocations", hasSize(org.hamcrest.Matchers.greaterThanOrEqualTo(1))));

    CustomerCreditOpeningBalance refreshedOpening = openingBalanceRepository.findById(openingBalance.getId())
        .orElseThrow();
    assertEquals(0, refreshedOpening.getRemainingAmount().compareTo(new BigDecimal("30.00")));
  }

  @Test
  @WithMockUser(roles = "CASHIER")
  void cashier_cannotCreateOrUpdateCustomer() throws Exception {
    mockMvc.perform(post("/api/customers")
        .contentType(MediaType.APPLICATION_JSON)
        .content("""
            {
              "type": "INDIVIDUAL",
              "nameEn": "No Create",
              "nameKm": "មិនអនុញ្ញាត",
              "phone": "012000000",
              "creditLimit": 0
            }
            """))
        .andExpect(status().isForbidden());

    mockMvc.perform(put("/api/customers/" + customer.getId())
        .contentType(MediaType.APPLICATION_JSON)
        .content("""
            {
              "type": "INDIVIDUAL",
              "nameEn": "No Update",
              "nameKm": "មិនអនុញ្ញាត",
              "phone": "012000000",
              "creditLimit": 0
            }
            """))
        .andExpect(status().isForbidden());
  }
}
