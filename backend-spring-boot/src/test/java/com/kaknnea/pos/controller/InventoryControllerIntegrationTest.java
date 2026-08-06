package com.kaknnea.pos.controller;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.StockItem;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.repository.CategoryRepository;
import com.kaknnea.pos.repository.InventorySnapshotRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.StoreRepository;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
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
class InventoryControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private StoreRepository storeRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private StockItemRepository stockItemRepository;

    @Autowired
    private InventorySnapshotRepository inventorySnapshotRepository;

    private Store storeOne;
    private Store storeTwo;
    private Product trackedProduct;
    private Category inventoryCategory;

    @BeforeEach
    void setUp() {
        String suffix = String.valueOf(System.nanoTime());

        storeOne = new Store();
        storeOne.setName("Main Store " + suffix);
        storeOne = storeRepository.save(storeOne);

        storeTwo = new Store();
        storeTwo.setName("Warehouse " + suffix);
        storeTwo = storeRepository.save(storeTwo);

        inventoryCategory = new Category();
        inventoryCategory.setNameEn("Inventory Test " + suffix);
        inventoryCategory.setNameKm("តេស្តស្តុក " + suffix);
        inventoryCategory = categoryRepository.save(inventoryCategory);

        trackedProduct = new Product();
        trackedProduct.setSku("INV-COFFEE-" + suffix);
        trackedProduct.setBarcode("INV-BC-" + suffix);
        trackedProduct.setNameEn("Coffee Bean " + suffix);
        trackedProduct.setNameKm("គ្រាប់កាហ្វេ " + suffix);
        trackedProduct.setCost(new BigDecimal("4.50"));
        trackedProduct.setPrice(new BigDecimal("7.50"));
        trackedProduct.setTrackInventory(true);
        trackedProduct.setPurchasable(true);
        trackedProduct.setLowStockThreshold(new BigDecimal("3.00"));
        trackedProduct.setCategory(inventoryCategory);
        trackedProduct = productRepository.save(trackedProduct);

        StockItem mainStock = new StockItem();
        mainStock.setProduct(trackedProduct);
        mainStock.setStore(storeOne);
        mainStock.setQuantity(new BigDecimal("7.00"));
        mainStock.setLowStockThreshold(new BigDecimal("3.00"));
        stockItemRepository.save(mainStock);

        StockItem warehouseStock = new StockItem();
        warehouseStock.setProduct(trackedProduct);
        warehouseStock.setStore(storeTwo);
        warehouseStock.setQuantity(new BigDecimal("15.00"));
        warehouseStock.setLowStockThreshold(new BigDecimal("5.00"));
        stockItemRepository.save(warehouseStock);
    }

    @Test
    @WithMockUser(authorities = "PERM_INVENTORY_MANAGE")
    void stockEndpoints_areStoreAware() throws Exception {
        mockMvc.perform(get("/api/inventory/stocks").param("storeId", storeOne.getId().toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].storeId").value(storeOne.getId()))
                .andExpect(jsonPath("$[0].quantity").value(7.0));

        mockMvc.perform(post("/api/inventory/stocks/in")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "productId", trackedProduct.getId(),
                                "storeId", storeTwo.getId(),
                                "quantity", 2,
                                "reason", "Manual receipt"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.storeId").value(storeTwo.getId()))
                .andExpect(jsonPath("$.quantity").value(17.0));
    }

    @Test
    @WithMockUser(authorities = "PERM_INVENTORY_MANAGE")
    void movements_normalizeLegacyTypesAndSnapshotIsPerStore() throws Exception {
        mockMvc.perform(post("/api/inventory/stocks/adjust")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "productId", trackedProduct.getId(),
                                "storeId", storeOne.getId(),
                                "quantity", -1,
                                "reason", "Damage"
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/inventory/movements").param("storeId", storeOne.getId().toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].movementType").value("ADJUSTMENT"))
                .andExpect(jsonPath("$[0].storeName").value(storeOne.getName()));

        LocalDate snapshotDate = LocalDate.of(2026, 3, 8);
        mockMvc.perform(post("/api/inventory/snapshots")
                        .param("date", snapshotDate.toString())
                        .param("storeId", storeOne.getId().toString()))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/inventory/snapshots")
                        .param("date", snapshotDate.toString())
                        .param("storeId", storeOne.getId().toString()))
                .andExpect(status().isBadRequest());
    }
}
