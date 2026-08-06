package com.kaknnea.pos.controller;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

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
import com.kaknnea.pos.domain.Unit;
import com.kaknnea.pos.repository.CategoryRepository;
import com.kaknnea.pos.repository.UnitRepository;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class ProductCatalogIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private UnitRepository unitRepository;

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "ROLE_OWNER",
            "PERM_PRODUCT_MANAGE",
            "PERM_POS_SALE",
            "PERM_INVENTORY_MANAGE",
            "PERM_PURCHASE_MANAGE"
    })
    void catalogEndpoints_respectSellableTrackedAndPurchasableBehavior() throws Exception {
        Category category = createCategory("Workflow Drinks", "ភេសជ្ជៈលំហូរ");
        Unit each = unitRepository.findByCode("EACH").orElseThrow();

        mockMvc.perform(post("/api/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "sku": "ING-API-%d",
                                  "barcode": "ING-API-%d",
                                  "nameEn": "Integration Ingredient",
                                  "nameKm": "គ្រឿងផ្សំសាកល្បង",
                                  "cost": 2.50,
                                  "price": 0,
                                  "active": true,
                                  "sellable": false,
                                  "purchasable": true,
                                  "trackInventory": true,
                                  "productType": "INGREDIENT",
                                  "lowStockThreshold": 3,
                                  "categoryId": %d,
                                  "saleUnitId": %d,
                                  "purchaseUnitId": %d,
                                  "stockUnitId": %d
                                }
                                """.formatted(System.nanoTime(), System.nanoTime(), category.getId(), each.getId(), each.getId(), each.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sellable", is(false)))
                .andExpect(jsonPath("$.trackInventory", is(true)))
                .andExpect(jsonPath("$.purchasable", is(true)));

        mockMvc.perform(post("/api/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "sku": "SRV-API-%d",
                                  "barcode": "SRV-API-%d",
                                  "nameEn": "Integration Service",
                                  "nameKm": "សេវាកម្មសាកល្បង",
                                  "cost": 0,
                                  "price": 12,
                                  "active": true,
                                  "sellable": true,
                                  "purchasable": false,
                                  "trackInventory": false,
                                  "productType": "SERVICE",
                                  "lowStockThreshold": 0,
                                  "categoryId": %d,
                                  "saleUnitId": %d,
                                  "purchaseUnitId": %d,
                                  "stockUnitId": %d
                                }
                                """.formatted(System.nanoTime(), System.nanoTime(), category.getId(), each.getId(), each.getId(), each.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sellable", is(true)))
                .andExpect(jsonPath("$.trackInventory", is(false)));

        mockMvc.perform(get("/api/products/pos-catalog"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].nameEn", hasItem("Integration Service")))
                .andExpect(jsonPath("$[*].nameEn", not(hasItem("Integration Ingredient"))));

        mockMvc.perform(get("/api/products/inventory-catalog"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].nameEn", hasItem("Integration Ingredient")))
                .andExpect(jsonPath("$[*].nameEn", not(hasItem("Integration Service"))));

        mockMvc.perform(get("/api/products/purchasable-catalog"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].nameEn", hasItem("Integration Ingredient")))
                .andExpect(jsonPath("$[*].nameEn", not(hasItem("Integration Service"))));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "ROLE_OWNER",
            "PERM_PRODUCT_MANAGE",
            "PERM_POS_SALE"
    })
    void priceLists_resolveCommercialPriceAndRejectOverlappingScope() throws Exception {
        Category category = createCategory("Workflow Retail", "លក់រាយលំហូរ");
        Unit each = unitRepository.findByCode("EACH").orElseThrow();

        String productResponse = mockMvc.perform(post("/api/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "sku": "PL-API-%d",
                                  "barcode": "PL-API-%d",
                                  "nameEn": "Price List Target",
                                  "nameKm": "ទំនិញបញ្ជីតម្លៃ",
                                  "cost": 5,
                                  "price": 10,
                                  "active": true,
                                  "sellable": true,
                                  "purchasable": false,
                                  "trackInventory": false,
                                  "productType": "SALE_ITEM",
                                  "lowStockThreshold": 0,
                                  "categoryId": %d,
                                  "saleUnitId": %d,
                                  "purchaseUnitId": %d,
                                  "stockUnitId": %d
                                }
                                """.formatted(System.nanoTime(), System.nanoTime(), category.getId(), each.getId(), each.getId(), each.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        Number productId = com.jayway.jsonpath.JsonPath.read(productResponse, "$.id");
        Instant startsAt = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        Instant endsAt = startsAt.plus(2, ChronoUnit.DAYS);

        mockMvc.perform(post("/api/price-lists")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Happy Hour",
                                  "currencyCode": "KHR",
                                  "priority": 10,
                                  "active": true,
                                  "startsAt": "%s",
                                  "endsAt": "%s",
                                  "items": [
                                    { "productId": %d, "price": 8.50 }
                                  ]
                                }
                                """.formatted(startsAt, endsAt, productId.longValue())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].price", is(8.50)));

        mockMvc.perform(post("/api/price-lists")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Overlap List",
                                  "currencyCode": "KHR",
                                  "priority": 5,
                                  "active": true,
                                  "startsAt": "%s",
                                  "endsAt": "%s",
                                  "items": [
                                    { "productId": %d, "price": 7.75 }
                                  ]
                                }
                                """.formatted(startsAt.plus(1, ChronoUnit.HOURS), endsAt.plus(1, ChronoUnit.HOURS), productId.longValue())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Price list date range overlaps with Happy Hour for the same store/customer scope")));

        mockMvc.perform(get("/api/products/pos-catalog"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.nameEn=='Price List Target')].resolvedPrice", hasItem(8.50)));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "ROLE_OWNER",
            "PERM_PRODUCT_MANAGE",
            "PERM_POS_SALE",
            "PERM_INVENTORY_MANAGE",
            "PERM_PURCHASE_MANAGE"
    })
    void productCreate_defaultsUnitsAndCatalogResponsesAlwaysExposeCodes() throws Exception {
        Category category = createCategory("Defaults", "លំនាំដើម");

        mockMvc.perform(post("/api/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "sku": "DEF-API-%d",
                                  "barcode": "DEF-API-%d",
                                  "nameEn": "Defaulted Unit Product",
                                  "nameKm": "ទំនិញឯកតាលំនាំដើម",
                                  "cost": 1.25,
                                  "price": 2.50,
                                  "active": true,
                                  "sellable": true,
                                  "purchasable": true,
                                  "trackInventory": true,
                                  "productType": "STOCK_ITEM",
                                  "lowStockThreshold": 5,
                                  "categoryId": %d
                                }
                                """.formatted(System.nanoTime(), System.nanoTime(), category.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.saleUnitId", notNullValue()))
                .andExpect(jsonPath("$.purchaseUnitId", notNullValue()))
                .andExpect(jsonPath("$.stockUnitId", notNullValue()))
                .andExpect(jsonPath("$.saleUnitCode", is("EACH")))
                .andExpect(jsonPath("$.purchaseUnitCode", is("EACH")))
                .andExpect(jsonPath("$.stockUnitCode", is("EACH")));

        mockMvc.perform(get("/api/products/purchasable-catalog"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.nameEn=='Defaulted Unit Product')].purchaseUnitCode", hasItem("EACH")));
    }

    @Test
    @WithMockUser(username = "owner@kaknnea.local", authorities = {
            "ROLE_OWNER",
            "PERM_PRODUCT_MANAGE",
            "PERM_POS_SALE",
            "PERM_INVENTORY_MANAGE",
            "PERM_PURCHASE_MANAGE"
    })
    void conversionRules_rejectUnitsThatAreNotConfiguredOnProducts() throws Exception {
        Category category = createCategory("Conversions", "បម្លែង");
        Unit each = unitRepository.findByCode("EACH").orElseThrow();

        Unit box = new Unit();
        box.setCode("BOX-" + System.nanoTime());
        box.setName("Box");
        box.setNameEn("Box");
        box.setNameKm("ប្រអប់");
        box.setSymbol("box");
        box.setBaseUnitGroup("COUNT");
        box.setActive(true);
        box = unitRepository.save(box);

        Unit bag = new Unit();
        bag.setCode("BAG-" + System.nanoTime());
        bag.setName("Bag");
        bag.setNameEn("Bag");
        bag.setNameKm("ថង់");
        bag.setSymbol("bag");
        bag.setBaseUnitGroup("COUNT");
        bag.setActive(true);
        bag = unitRepository.save(bag);

        String sourceResponse = mockMvc.perform(post("/api/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "sku": "SRC-API-%d",
                                  "barcode": "SRC-API-%d",
                                  "nameEn": "Source Product",
                                  "nameKm": "ទំនិញប្រភព",
                                  "cost": 3,
                                  "price": 5,
                                  "active": true,
                                  "sellable": true,
                                  "purchasable": true,
                                  "trackInventory": true,
                                  "productType": "STOCK_ITEM",
                                  "lowStockThreshold": 2,
                                  "categoryId": %d,
                                  "saleUnitId": %d,
                                  "purchaseUnitId": %d,
                                  "stockUnitId": %d
                                }
                                """.formatted(System.nanoTime(), System.nanoTime(), category.getId(), each.getId(), box.getId(), each.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String targetResponse = mockMvc.perform(post("/api/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "sku": "TGT-API-%d",
                                  "barcode": "TGT-API-%d",
                                  "nameEn": "Target Product",
                                  "nameKm": "ទំនិញគោលដៅ",
                                  "cost": 4,
                                  "price": 7,
                                  "active": true,
                                  "sellable": true,
                                  "purchasable": true,
                                  "trackInventory": true,
                                  "productType": "STOCK_ITEM",
                                  "lowStockThreshold": 2,
                                  "categoryId": %d,
                                  "saleUnitId": %d,
                                  "purchaseUnitId": %d,
                                  "stockUnitId": %d
                                }
                                """.formatted(System.nanoTime(), System.nanoTime(), category.getId(), each.getId(), each.getId(), box.getId())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        Number sourceId = com.jayway.jsonpath.JsonPath.read(sourceResponse, "$.id");
        Number targetId = com.jayway.jsonpath.JsonPath.read(targetResponse, "$.id");

        mockMvc.perform(post("/api/product-conversions")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "sourceProductId": %d,
                                  "targetProductId": %d,
                                  "sourceUnitId": %d,
                                  "targetUnitId": %d,
                                  "ratio": 2,
                                  "conversionType": "PURCHASE_TO_STOCK",
                                  "active": true
                                }
                                """.formatted(sourceId.longValue(), targetId.longValue(), bag.getId(), box.getId())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Source unit is not configured on the source product")));
    }

    private Category createCategory(String nameEn, String nameKm) {
        Category category = new Category();
        category.setNameEn(nameEn);
        category.setNameKm(nameKm);
        category.setActive(true);
        return categoryRepository.save(category);
    }
}
