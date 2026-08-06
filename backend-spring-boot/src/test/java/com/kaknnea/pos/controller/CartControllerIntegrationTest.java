package com.kaknnea.pos.controller;

import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.dto.CartDtos;
import com.kaknnea.pos.repository.*;
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

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class CartControllerIntegrationTest {

        @Autowired
        private MockMvc mockMvc;

        // Removed unused field: cartRepository
        @Autowired
        private CustomerRepository customerRepository;

        @Autowired
        private ProductRepository productRepository;

        @Autowired
        private CategoryRepository categoryRepository;

        @Autowired
        private StoreRepository storeRepository;

        private Customer customer;
        private Product product;
        private Store store;
        // Removed unused field: cartId

        @BeforeEach
        void setUp() {
                // Create test store
                store = new Store();
                store.setName("Test Store");
                store.setAddress("123 Test Street");
                store.setPhone("555-0000");
                store = storeRepository.save(store);

                // Create test category
                Category category = new Category();
                category.setNameEn("Test Category");
                category.setNameKm("ក្រុមផលិតផលសាកល្បង");
                category.setActive(true);
                category = categoryRepository.save(category);

                // Create test data
                customer = new Customer();
                customer.setCustomerCode("CUST-CART-T01");
                customer.setNameEn("Test Customer");
                customer.setNameKm("ម៉ាកឌីលលី");
                customer.setPhone("012345678");
                customer.setType("REGULAR");
                customer.setCreditBalance(new BigDecimal("1000.00"));
                customer.setCreditLimit(new BigDecimal("1000.00"));
                customer = customerRepository.save(customer);

                product = new Product();
                product.setNameEn("Test Product");
                product.setNameKm("ផលិតផលសាកល្បង");
                product.setSku("TEST-001");
                product.setBarcode("BAR-TEST-001");
                product.setPrice(new BigDecimal("5.00"));
                product.setCost(new BigDecimal("2.00"));
                product.setActive(true);
                product.setCategory(category);
                product = productRepository.save(product);
        }

        // ============ CREATE CART TESTS ============

        @Test
        @WithMockUser(roles = "CASHIER")
        void testCreateCart_Success() throws Exception {
                // Given
                CartDtos.CreateCartRequest request = new CartDtos.CreateCartRequest();
                request.setCustomerId(customer.getId());
                request.setStoreId(store.getId());

                // When & Then
                MvcResult result = mockMvc.perform(post("/api/carts")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"customerId\":" + customer.getId() + ",\"storeId\":" + store.getId() + "}"))
                                .andExpect(status().isCreated())
                                .andExpect(jsonPath("$.id", notNullValue()))
                                .andExpect(jsonPath("$.customerId", is(customer.getId().intValue())))
                                .andExpect(jsonPath("$.status", is("ACTIVE")))
                                .andExpect(jsonPath("$.totalAmount", is(0)))
                                .andExpect(jsonPath("$.itemCount", is(0)))
                                .andReturn();

                // Extract cart ID for use in subsequent tests
                String responseBody = result.getResponse().getContentAsString();
                Long cartId = Long.parseLong(responseBody.split("\"id\":")[1].split(",")[0]);
        }

        @Test
        @WithMockUser(roles = "USER")
        void testCreateCart_Unauthorized() throws Exception {
                // Given
                String request = "{\"customerId\":" + customer.getId() + ",\"storeId\":" + store.getId() + "}";

                // When & Then
                mockMvc.perform(post("/api/carts")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(request))
                                .andExpect(status().isForbidden());
        }

        @Test
        void testCreateCart_Unauthenticated() throws Exception {
                // Given
                String request = "{\"customerId\":" + customer.getId() + ",\"storeId\":" + store.getId() + "}";

                // When & Then
                mockMvc.perform(post("/api/carts")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(request))
                                .andExpect(status().isForbidden());
        }

        // ============ ADD ITEM TO CART TESTS ============

        @Test
        @WithMockUser(roles = "CASHIER")
        void testAddItemToCart_Success() throws Exception {
                // Given: Create a cart first
                MvcResult createResult = mockMvc.perform(post("/api/carts")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"customerId\":" + customer.getId() + ",\"storeId\":" + store.getId() + "}"))
                                .andExpect(status().isCreated())
                                .andReturn();

                String responseBody = createResult.getResponse().getContentAsString();
                Long cartId = Long.parseLong(responseBody.split("\"id\":")[1].split(",")[0]);

                // When & Then: Add item to cart
                mockMvc.perform(post("/api/carts/" + cartId + "/items")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"productId\":" + product.getId() + ",\"quantity\":5}"))
                                .andExpect(status().isCreated())
                                .andExpect(jsonPath("$.productId", is(product.getId().intValue())))
                                .andExpect(jsonPath("$.quantity", is(5)))
                                .andExpect(jsonPath("$.unitPrice", is(5.0)))
                                .andExpect(jsonPath("$.totalPrice", is(25.0)));
        }

        @Test
        @WithMockUser(roles = "CASHIER")
        void testAddItemToCart_InvalidQuantity() throws Exception {
                // Given: Create a cart
                MvcResult createResult = mockMvc.perform(post("/api/carts")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"customerId\":" + customer.getId() + ",\"storeId\":" + store.getId() + "}"))
                                .andExpect(status().isCreated())
                                .andReturn();

                String responseBody = createResult.getResponse().getContentAsString();
                Long cartId = Long.parseLong(responseBody.split("\"id\":")[1].split(",")[0]);

                // When & Then: Try to add with invalid quantity
                mockMvc.perform(post("/api/carts/" + cartId + "/items")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"productId\":" + product.getId() + ",\"quantity\":0}"))
                                .andExpect(status().isBadRequest());
        }

        // ============ GET CART TESTS ============

        @Test
        @WithMockUser(roles = "CASHIER")
        void testGetCart_Success() throws Exception {
                // Given: Create a cart
                MvcResult createResult = mockMvc.perform(post("/api/carts")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"customerId\":" + customer.getId() + ",\"storeId\":" + store.getId() + "}"))
                                .andExpect(status().isCreated())
                                .andReturn();

                String responseBody = createResult.getResponse().getContentAsString();
                Long cartId = Long.parseLong(responseBody.split("\"id\":")[1].split(",")[0]);

                // When & Then: Retrieve the cart
                mockMvc.perform(get("/api/carts/" + cartId))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.id", is(cartId.intValue())))
                                .andExpect(jsonPath("$.customerId", is(customer.getId().intValue())))
                                .andExpect(jsonPath("$.status", is("ACTIVE")));
        }

        @Test
        @WithMockUser(roles = "CASHIER")
        void testGetCart_NotFound() throws Exception {
                // When & Then
                mockMvc.perform(get("/api/carts/999999"))
                                .andExpect(status().isBadRequest());
        }

        // ============ CLEAR CART TESTS ============

        @Test
        @WithMockUser(roles = "CASHIER")
        void testClearCart_Success() throws Exception {
                // Given: Create a cart and add item
                MvcResult createResult = mockMvc.perform(post("/api/carts")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"customerId\":" + customer.getId() + ",\"storeId\":" + store.getId() + "}"))
                                .andExpect(status().isCreated())
                                .andReturn();

                String responseBody = createResult.getResponse().getContentAsString();
                Long cartId = Long.parseLong(responseBody.split("\"id\":")[1].split(",")[0]);

                // When: Clear the cart
                mockMvc.perform(delete("/api/carts/" + cartId))
                                .andExpect(status().isNoContent());

                // Then: Verify cart is empty
                mockMvc.perform(get("/api/carts/" + cartId))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.itemCount", is(0)))
                                .andExpect(jsonPath("$.items", hasSize(0)));
        }

        // ============ CHECKOUT TESTS ============

        @Test
        @WithMockUser(roles = "CASHIER")
        void testCompleteCart_Success() throws Exception {
                // Given: Create a cart
                MvcResult createResult = mockMvc.perform(post("/api/carts")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"customerId\":" + customer.getId() + ",\"storeId\":" + store.getId() + "}"))
                                .andExpect(status().isCreated())
                                .andReturn();

                String responseBody = createResult.getResponse().getContentAsString();
                Long cartId = Long.parseLong(responseBody.split("\"id\":")[1].split(",")[0]);

                // When & Then: Complete the cart
                mockMvc.perform(post("/api/carts/" + cartId + "/checkout"))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.cartId", is(cartId.intValue())))
                                .andExpect(jsonPath("$.status", is("COMPLETED")))
                                .andExpect(jsonPath("$.message", containsString("successfully")));
        }
}
