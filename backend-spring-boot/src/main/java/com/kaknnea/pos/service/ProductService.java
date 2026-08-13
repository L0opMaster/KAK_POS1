package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.ProductBundleComponent;
import com.kaknnea.pos.domain.ProductImage;
import com.kaknnea.pos.domain.ProductUnitConversion;
import com.kaknnea.pos.domain.PriceList;
import com.kaknnea.pos.domain.PriceListItem;
import com.kaknnea.pos.domain.StockItem;
import com.kaknnea.pos.domain.StockMovement;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.domain.ProductionRecipe;
import com.kaknnea.pos.domain.ProductionRecipeLine;
import com.kaknnea.pos.domain.Unit;
import com.kaknnea.pos.dto.ProductConversionDtos;
import com.kaknnea.pos.dto.ProductDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.mapper.ProductMapper;
import com.kaknnea.pos.repository.CategoryRepository;
import com.kaknnea.pos.repository.GoodsReceiptRepository;
import com.kaknnea.pos.repository.InventorySnapshotRepository;
import com.kaknnea.pos.repository.ProductUnitConversionRepository;
import com.kaknnea.pos.repository.ProductBundleComponentRepository;
import com.kaknnea.pos.repository.PriceListRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.ProductionRecipeRepository;
import com.kaknnea.pos.repository.PurchaseRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.StockMovementRepository;
import com.kaknnea.pos.repository.StockTransferRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.SupplierInvoiceRepository;
import com.kaknnea.pos.repository.UnitRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.SecurityUtil;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicInteger;

@Service
public class ProductService {
        private final ProductRepository productRepository;
        private final CategoryRepository categoryRepository;
        private final ProductMapper productMapper;
        private final AuditService auditService;
        private final UserRepository userRepository;
        private final StockItemRepository stockItemRepository;
        private final UnitRepository unitRepository;
        private final ProductUnitConversionRepository conversionRepository;
        private final ProductBundleComponentRepository bundleComponentRepository;
        private final PriceListRepository priceListRepository;
        private final ProductionRecipeRepository productionRecipeRepository;
        private final StockMovementRepository stockMovementRepository;
        private final PurchaseRepository purchaseRepository;
        private final SaleRepository saleRepository;
        private final GoodsReceiptRepository goodsReceiptRepository;
        private final SupplierInvoiceRepository supplierInvoiceRepository;
        private final StockTransferRepository stockTransferRepository;
        private final InventorySnapshotRepository inventorySnapshotRepository;
        private final StoreRepository storeRepository;

        @PersistenceContext
        private EntityManager entityManager;

        public ProductService(ProductRepository productRepository, CategoryRepository categoryRepository,
                        ProductMapper productMapper,
                        AuditService auditService, UserRepository userRepository,
                        StockItemRepository stockItemRepository,
                        UnitRepository unitRepository,
                        ProductUnitConversionRepository conversionRepository,
                        ProductBundleComponentRepository bundleComponentRepository,
                        PriceListRepository priceListRepository,
                        ProductionRecipeRepository productionRecipeRepository,
                        StockMovementRepository stockMovementRepository,
                        PurchaseRepository purchaseRepository,
                        SaleRepository saleRepository,
                        GoodsReceiptRepository goodsReceiptRepository,
                        SupplierInvoiceRepository supplierInvoiceRepository,
                        StockTransferRepository stockTransferRepository,
                        InventorySnapshotRepository inventorySnapshotRepository,
                        StoreRepository storeRepository) {
                this.productRepository = productRepository;
                this.categoryRepository = categoryRepository;
                this.productMapper = productMapper;
                this.auditService = auditService;
                this.userRepository = userRepository;
                this.stockItemRepository = stockItemRepository;
                this.unitRepository = unitRepository;
                this.conversionRepository = conversionRepository;
                this.bundleComponentRepository = bundleComponentRepository;
                this.priceListRepository = priceListRepository;
                this.productionRecipeRepository = productionRecipeRepository;
                this.stockMovementRepository = stockMovementRepository;
                this.purchaseRepository = purchaseRepository;
                this.saleRepository = saleRepository;
                this.goodsReceiptRepository = goodsReceiptRepository;
                this.supplierInvoiceRepository = supplierInvoiceRepository;
                this.stockTransferRepository = stockTransferRepository;
                this.inventorySnapshotRepository = inventorySnapshotRepository;
                this.storeRepository = storeRepository;
        }

        @Transactional(readOnly = true)
        public Page<ProductDtos.ProductResponse> search(String q, Long categoryId, Boolean active, Boolean sellable,
                        Boolean stockTracked, Boolean purchasable, Long storeId, String productType, Pageable pageable) {
                String normalizedType = productType == null || productType.isBlank() ? null : productType.trim().toUpperCase(Locale.ROOT);
                Page<Product> page = productRepository.search(
                                q == null ? "" : q.trim(),
                                categoryId,
                                active,
                                sellable,
                                stockTracked,
                                purchasable,
                                normalizedType,
                                pageable);
                Map<Long, BigDecimal> reservedQtyByProductId = reservedSaleQtyMap(storeId, page.getContent());
                return page.map(product -> toProductResponse(
                                product,
                                storeId,
                                reservedQtyByProductId.getOrDefault(product.getId(), BigDecimal.ZERO)));
        }

        @Transactional
        public ProductDtos.ProductResponse create(ProductDtos.ProductRequest request) {
                Product product = new Product();
                apply(product, request);
                Product saved = productRepository.save(product);
                if (saved.isTrackInventory()
                                && request.getInitialStock() != null
                                && request.getInitialStock().compareTo(BigDecimal.ZERO) > 0) {
                        ensureStockItem(saved, request.getInitialStock());
                }
                var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
                auditService.log(actor, "PRODUCT_CREATE", "Product", String.valueOf(saved.getId()), null, saved);
                return toProductResponse(saved);
        }

        @Transactional
        public ProductDtos.ProductResponse update(Long id, ProductDtos.ProductRequest request) {
                Product product = productRepository.findById(id)
                                .orElseThrow(() -> new ApiException("Product not found"));
                Product before = new Product();
                before.setId(product.getId());
                before.setSku(product.getSku());
                before.setBarcode(product.getBarcode());
                before.setNameEn(product.getNameEn());
                before.setNameKm(product.getNameKm());
                before.setImageUrl(product.getImageUrl());
                before.setDescription(product.getDescription());
                before.setCost(product.getCost());
                before.setPrice(product.getPrice());
                before.setActive(product.isActive());
                before.setSellable(product.isSellable());
                before.setPurchasable(product.isPurchasable());
                before.setTrackInventory(product.isTrackInventory());
                before.setProductType(product.getProductType());
                before.setLowStockThreshold(product.getLowStockThreshold());
                before.setVariantLabel(product.getVariantLabel());
                before.setBundleMode(product.getBundleMode());
                apply(product, request);
                Product saved = productRepository.save(product);
                var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
                auditService.log(actor, "PRODUCT_UPDATE", "Product", String.valueOf(saved.getId()), before, saved);
                return toProductResponse(saved);
        }

        @Transactional
        public void delete(Long id) {
                Product product = productRepository.findById(id)
                                .orElseThrow(() -> new ApiException("Product not found"));
                boolean hasStock = stockItemRepository.findAllByProductId(id).stream()
                                .anyMatch(item -> item.getQuantity() != null && item.getQuantity().compareTo(BigDecimal.ZERO) > 0);
                boolean hasMovements = stockMovementRepository.existsByProductId(id);
                boolean hasGoodsReceipts = goodsReceiptRepository.existsByLinesProductId(id);
                boolean hasSupplierInvoices = supplierInvoiceRepository.existsByLinesProductId(id);
                if (hasStock || hasMovements || hasGoodsReceipts || hasSupplierInvoices) {
                        throw new ApiException("Product has stock or history. Archive it instead of deleting.");
                }
                var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
                auditService.log(actor, "PRODUCT_DELETE", "Product", String.valueOf(product.getId()), product, null);
                productRepository.delete(product);
        }

        @Transactional
        public ProductDtos.ProductResponse archive(Long id) {
                Product product = productRepository.findById(id)
                                .orElseThrow(() -> new ApiException("Product not found"));
                product.setActive(false);
                product.setSellable(false);
                Product saved = productRepository.save(product);
                var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
                auditService.log(actor, "PRODUCT_ARCHIVE", "Product", String.valueOf(saved.getId()), null, saved);
                return toProductResponse(saved);
        }

        @Transactional(readOnly = true)
        public List<ProductDtos.ProductResponse> posCatalog(Long storeId) {
                List<Product> products = productRepository.findAllByActiveTrueAndSellableTrueOrderByNameEnAsc();
                Map<Long, BigDecimal> reservedQtyByProductId = reservedSaleQtyMap(storeId, products);
                return products.stream()
                                .map(product -> toProductResponse(
                                                product,
                                                storeId,
                                                reservedQtyByProductId.getOrDefault(product.getId(), BigDecimal.ZERO)))
                                .toList();
        }

        @Transactional(readOnly = true)
        public List<ProductDtos.ProductResponse> inventoryCatalog(Long storeId) {
                List<Product> products = productRepository.findAllByActiveTrueAndTrackInventoryTrueOrderByNameEnAsc();
                Map<Long, BigDecimal> reservedQtyByProductId = reservedSaleQtyMap(storeId, products);
                return products.stream()
                                .map(product -> toProductResponse(
                                                product,
                                                storeId,
                                                reservedQtyByProductId.getOrDefault(product.getId(), BigDecimal.ZERO)))
                                .toList();
        }

        @Transactional(readOnly = true)
        public List<ProductDtos.ProductResponse> purchasableCatalog(Long storeId) {
                List<Product> products = productRepository.findAllByActiveTrueAndPurchasableTrueOrderByNameEnAsc();
                Map<Long, BigDecimal> reservedQtyByProductId = reservedSaleQtyMap(storeId, products);
                return products.stream()
                                .map(product -> toProductResponse(
                                                product,
                                                storeId,
                                                reservedQtyByProductId.getOrDefault(product.getId(), BigDecimal.ZERO)))
                                .toList();
        }

        @Transactional(readOnly = true)
        public ProductConversionDtos.ProductHistoryResponse history(Long productId) {
                productRepository.findById(productId).orElseThrow(() -> new ApiException("Product not found"));
                List<ProductConversionDtos.HistoryEntry> entries = new ArrayList<>();

                stockMovementRepository.findAllByProductIdOrderByCreatedAtDesc(productId).forEach(movement -> {
                        ProductConversionDtos.HistoryEntry entry = new ProductConversionDtos.HistoryEntry();
                        entry.setSource("STOCK");
                        entry.setEventType(movement.getMovementType());
                        entry.setQuantity(movement.getQuantity());
                        entry.setNotes(movement.getReason());
                        entry.setCreatedAt(movement.getCreatedAt().toString());
                        entries.add(entry);
                });

                addHistoryRows(entries, "PURCHASE", purchaseRepository.findProductHistoryRows(productId));
                addHistoryRows(entries, "GRN", goodsReceiptRepository.findProductHistoryRows(productId));
                addHistoryRows(entries, "SUPPLIER_INVOICE", supplierInvoiceRepository.findProductHistoryRows(productId));
                addHistoryRows(entries, "TRANSFER", stockTransferRepository.findProductHistoryRows(productId));
                addHistoryRows(entries, "COUNT", inventorySnapshotRepository.findProductHistoryRows(productId));

                entries.sort((left, right) -> right.getCreatedAt().compareTo(left.getCreatedAt()));
                ProductConversionDtos.ProductHistoryResponse response = new ProductConversionDtos.ProductHistoryResponse();
                response.setEntries(entries);
                return response;
        }

        private void addHistoryRows(
                        List<ProductConversionDtos.HistoryEntry> entries,
                        String source,
                        List<Object[]> rows) {
                rows.forEach(row -> {
                        ProductConversionDtos.HistoryEntry entry = new ProductConversionDtos.HistoryEntry();
                        entry.setSource(source);
                        entry.setEventType((String) row[0]);
                        entry.setQuantity((BigDecimal) row[1]);
                        entry.setNotes(row[2] == null ? null : row[2].toString());
                        entry.setCreatedAt(row[3] == null ? null : row[3].toString());
                        entries.add(entry);
                });
        }

        @Transactional
        public ProductDtos.SampleSeedResponse seedSampleProducts(ProductDtos.SampleSeedRequest request) {
                String businessType = request != null && request.getBusinessType() != null
                                ? request.getBusinessType().trim().toUpperCase(Locale.ROOT)
                                : "";
                if (businessType.isBlank()) {
                        throw new ApiException("Business type is required");
                }

                if (request != null && Boolean.TRUE.equals(request.getResetAll())) {
                        resetAllCommerceData();
                }

                SeedPlan plan = buildSeedPlan(businessType);
                if (plan == null) {
                        throw new ApiException("Unsupported business type");
                }

                AtomicInteger categoriesCreated = new AtomicInteger(0);
                AtomicInteger productsCreated = new AtomicInteger(0);
                Map<String, Category> categoryMap = new HashMap<>();
                Map<String, Product> seededProducts = new HashMap<>();

                for (String categoryNameEn : plan.categories) {
                        Category category = categoryRepository.findFirstByNameEnIgnoreCase(categoryNameEn)
                                        .orElseGet(() -> {
                                                Category created = new Category();
                                                created.setNameEn(categoryNameEn);
                                                created.setNameKm(plan.categoryKmNames.getOrDefault(categoryNameEn,
                                                                categoryNameEn));
                                                created.setActive(true);
                                                categoriesCreated.incrementAndGet();
                                                return categoryRepository.save(created);
                                        });
                        categoryMap.put(categoryNameEn, category);
                }

                for (SeedProduct item : plan.products) {
                        Category category = categoryMap.get(item.categoryNameEn);
                        if (category == null) {
                                continue;
                        }
                        Product existing = productRepository.findFirstBySku(item.sku).orElse(null);
                        Product product = existing != null ? existing : new Product();
                        product.setSku(item.sku);
                        product.setBarcode(item.barcode);
                        product.setNameEn(item.nameEn);
                        product.setNameKm(item.nameKm);
                        product.setCost(item.cost);
                        product.setPrice(item.price);
                        product.setActive(true);
                        product.setSellable(item.sellable);
                        product.setPurchasable(item.purchasable);
                        product.setTrackInventory(item.trackInventory);
                        product.setProductType(item.productType);
                        product.setLowStockThreshold(item.lowStockThreshold);
                        product.setCategory(category);
                        product.setSaleUnit(resolveUnitByCode(item.saleUnitCode));
                        product.setPurchaseUnit(resolveUnitByCode(item.purchaseUnitCode));
                        product.setStockUnit(resolveUnitByCode(item.stockUnitCode));
                        Product saved = productRepository.save(product);
                        seededProducts.put(item.sku, saved);
                        if (existing == null) {
                                productsCreated.incrementAndGet();
                        }
                        if (item.initialStock != null && item.trackInventory) {
                                ensureStockItem(saved, item.initialStock);
                        }
                }

                seedProductionScenarioIfNeeded(businessType, seededProducts);

                ProductDtos.SampleSeedResponse response = new ProductDtos.SampleSeedResponse();
                response.setBusinessType(businessType);
                response.setCategoriesCreated(categoriesCreated.get());
                response.setProductsCreated(productsCreated.get());
                return response;
        }

        private void resetAllCommerceData() {
                entityManager.createNativeQuery("SET FOREIGN_KEY_CHECKS=0").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM payment_audit_log").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM transactions").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM payments").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM sale_discounts").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM sale_lines").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM sale_items").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM sales").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM cart_items").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM carts").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM production_order_lines").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM production_orders").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM production_recipe_lines").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM production_recipes").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM stock_movements").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM stock_items").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM stocks").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM product_images").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM product_modifier_groups").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM products").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM categories").executeUpdate();
                entityManager.createNativeQuery("DELETE FROM customer_credit_accounts").executeUpdate();
                entityManager.createNativeQuery("UPDATE customers SET credit_balance = 0").executeUpdate();
                entityManager.createNativeQuery("SET FOREIGN_KEY_CHECKS=1").executeUpdate();
        }

        private SeedPlan buildSeedPlan(String businessType) {
                switch (businessType) {
                        case "COFFEE_SHOP":
                                return SeedPlan.coffeeShop();
                        case "RESTAURANT":
                                return SeedPlan.restaurant();
                        case "MART":
                                return SeedPlan.mart();
                        case "BAKERY":
                                return SeedPlan.bakery();
                        case "SALON":
                                return SeedPlan.salon();
                        case "MEATBALL_RETAIL":
                                return SeedPlan.meatballRetail();
                        case "WHOLESALE":
                                return SeedPlan.wholesale();
                        case "PRODUCTION":
                                return SeedPlan.production();
                        default:
                                return null;
                }
        }

        private void apply(Product product, ProductDtos.ProductRequest request) {
                product.setSku(request.getSku().trim());
                product.setBarcode(request.getBarcode().trim());
                product.setNameEn(request.getNameEn().trim());
                product.setNameKm(request.getNameKm().trim());
                product.setImageUrl(request.getImageUrl());
                product.setDescription(request.getDescription() == null || request.getDescription().isBlank()
                                ? null
                                : request.getDescription().trim());
                product.setCost(request.getCost());
                product.setPrice(request.getPrice());
                product.setActive(request.isActive());
                product.setSellable(request.isSellable());
                product.setPurchasable(request.isPurchasable());
                product.setTrackInventory(request.isTrackInventory());
                product.setProductType(request.getProductType().trim().toUpperCase(Locale.ROOT));
                product.setVariantLabel(request.getVariantLabel() == null || request.getVariantLabel().isBlank() ? null : request.getVariantLabel().trim());
                product.setBundleMode(request.getBundleMode() == null || request.getBundleMode().isBlank() ? null : request.getBundleMode().trim().toUpperCase(Locale.ROOT));
                product.setLowStockThreshold(request.getLowStockThreshold());
                if (request.getCategoryId() == null) {
                        throw new ApiException("Category is required");
                }
                Category category = categoryRepository.findById(request.getCategoryId())
                                .orElseThrow(() -> new ApiException("Category not found"));
                product.setCategory(category);
                Unit defaultUnit = defaultUnit();
                product.setSaleUnit(resolveUnit(request.getSaleUnitId(), defaultUnit.getId()));
                product.setPurchaseUnit(resolveUnit(request.getPurchaseUnitId(), defaultUnit.getId()));
                product.setStockUnit(resolveUnit(request.getStockUnitId(), defaultUnit.getId()));
                if (request.getParentProductId() != null) {
                        Product parent = productRepository.findById(request.getParentProductId())
                                        .orElseThrow(() -> new ApiException("Parent product not found"));
                        if (product.getId() != null && product.getId().equals(parent.getId())) {
                                throw new ApiException("Product cannot be its own parent");
                        }
                        product.setParentProduct(parent);
                } else {
                        product.setParentProduct(null);
                }
                validateProduct(product);
                applyImages(product, request);
                applyBundleComponents(product, request);
        }

        private Unit resolveUnit(Long unitId, Long defaultId) {
                Long resolvedId = unitId != null ? unitId : defaultId;
                return unitRepository.findById(resolvedId)
                                .orElseThrow(() -> new ApiException("Unit not found"));
        }

        private Unit defaultUnit() {
                return unitRepository.findByCode("EACH")
                                .orElseThrow(() -> new ApiException("Default unit missing"));
        }

        private Unit resolveUnitByCode(String unitCode) {
                if (unitCode == null || unitCode.isBlank()) {
                        return defaultUnit();
                }
                return unitRepository.findByCode(unitCode.trim().toUpperCase(Locale.ROOT))
                                .orElseGet(this::defaultUnit);
        }

        private Store resolvePrimaryStore() {
                return storeRepository.findById(1L)
                                .orElseGet(() -> storeRepository.findAll().stream().findFirst().orElseGet(() -> {
                                        Store store = new Store();
                                        store.setName("Main Store");
                                        return storeRepository.save(store);
                                }));
        }

        private void ensureStockItem(Product product, BigDecimal quantity) {
                Store store = resolvePrimaryStore();
                StockItem stockItem = stockItemRepository.findByProductIdAndStoreId(product.getId(), store.getId())
                                .orElseGet(() -> {
                                        StockItem item = new StockItem();
                                        item.setProduct(product);
                                        item.setStore(store);
                                        item.setQuantity(BigDecimal.ZERO);
                                        item.setLowStockThreshold(product.getLowStockThreshold());
                                        return item;
                                });
                stockItem.setQuantity(quantity);
                stockItem.setLowStockThreshold(product.getLowStockThreshold());
                stockItemRepository.save(stockItem);
        }

        private void seedProductionScenarioIfNeeded(String businessType, Map<String, Product> seededProducts) {
                if (!"PRODUCTION".equals(businessType)) {
                        return;
                }
                Product outputProduct = seededProducts.get("MB-FIN-001");
                if (outputProduct == null) {
                        return;
                }
                boolean exists = productionRecipeRepository.existsByOutputProductIdAndNameIgnoreCase(
                                outputProduct.getId(),
                                "Beef Meatball Base Batch");
                if (exists) {
                        return;
                }

                ProductionRecipe recipe = new ProductionRecipe();
                recipe.setName("Beef Meatball Base Batch");
                recipe.setOutputProduct(outputProduct);
                recipe.setOutputQuantity(new BigDecimal("20.00"));
                recipe.setActive(true);
                recipe.setNotes("Sample recipe for beef meatball production: 20 retail packs per batch.");
                recipe.setLines(new ArrayList<>());

                addRecipeLine(recipe, seededProducts.get("MB-RAW-001"), new BigDecimal("8.00"));
                addRecipeLine(recipe, seededProducts.get("MB-RAW-002"), new BigDecimal("1.00"));
                addRecipeLine(recipe, seededProducts.get("MB-RAW-003"), new BigDecimal("0.40"));
                addRecipeLine(recipe, seededProducts.get("MB-RAW-004"), new BigDecimal("0.20"));
                addRecipeLine(recipe, seededProducts.get("MB-RAW-005"), new BigDecimal("0.15"));
                addRecipeLine(recipe, seededProducts.get("MB-RAW-006"), new BigDecimal("0.05"));
                addRecipeLine(recipe, seededProducts.get("MB-RAW-007"), new BigDecimal("1.20"));
                addRecipeLine(recipe, seededProducts.get("MB-PKG-001"), new BigDecimal("20.00"));

                productionRecipeRepository.save(recipe);
        }

        private void addRecipeLine(ProductionRecipe recipe, Product componentProduct, BigDecimal quantity) {
                if (componentProduct == null) {
                        return;
                }
                ProductionRecipeLine line = new ProductionRecipeLine();
                line.setRecipe(recipe);
                line.setComponentProduct(componentProduct);
                line.setComponentQuantity(quantity);
                recipe.getLines().add(line);
        }

        private void validateProduct(Product product) {
                if (product.isSellable() && product.getPrice() == null) {
                        throw new ApiException("Sellable products require a price");
                }
                if (product.isTrackInventory() && product.getLowStockThreshold() == null) {
                        throw new ApiException("Tracked products require a low stock threshold");
                }
                if (product.isPurchasable() && product.getPurchaseUnit() == null) {
                        throw new ApiException("Purchasable products require a purchase unit");
                }
                if (!List.of("SALE_ITEM", "STOCK_ITEM", "SERVICE", "INGREDIENT", "CONVERSION_ONLY")
                                .contains(product.getProductType())) {
                        if (!List.of("VARIANT_PARENT", "VARIANT", "BUNDLE").contains(product.getProductType())) {
                                throw new ApiException("Unsupported product type");
                        }
                }
                if ("VARIANT".equals(product.getProductType()) && product.getParentProduct() == null) {
                        throw new ApiException("Variants require a parent product");
                }
                if ("BUNDLE".equals(product.getProductType()) && product.getBundleMode() == null) {
                        throw new ApiException("Bundles require a bundle mode");
                }
        }

        private void applyBundleComponents(Product product, ProductDtos.ProductRequest request) {
                product.getBundleComponents().clear();
                if (!"BUNDLE".equals(product.getProductType())) {
                        return;
                }
                if (request.getBundleComponents() == null || request.getBundleComponents().isEmpty()) {
                        throw new ApiException("Bundles require at least one component");
                }
                for (ProductDtos.ProductBundleComponentRequest componentRequest : request.getBundleComponents()) {
                        Product componentProduct = productRepository.findById(componentRequest.getComponentProductId())
                                        .orElseThrow(() -> new ApiException("Bundle component product not found"));
                        if (product.getId() != null && product.getId().equals(componentProduct.getId())) {
                                throw new ApiException("Bundle cannot include itself");
                        }
                        ProductBundleComponent component = new ProductBundleComponent();
                        component.setBundleProduct(product);
                        component.setComponentProduct(componentProduct);
                        component.setComponentQuantity(componentRequest.getComponentQuantity());
                        product.getBundleComponents().add(component);
                }
        }

        private ProductDtos.ProductResponse toProductResponse(Product product) {
                return toProductResponse(product, null, BigDecimal.ZERO);
        }

        private ProductDtos.ProductResponse toProductResponse(Product product, Long storeId) {
                return toProductResponse(product, storeId, BigDecimal.ZERO);
        }

        private ProductDtos.ProductResponse toProductResponse(Product product, Long storeId, BigDecimal reservedSaleQty) {
                ProductDtos.ProductResponse response = productMapper.toResponse(product);
                Unit defaultUnit = defaultUnit();
                if (response.getSaleUnitId() == null) {
                        response.setSaleUnitId(defaultUnit.getId());
                        response.setSaleUnitCode(defaultUnit.getCode());
                }
                response.setSaleUnitBaseGroup(unitBaseGroup(product.getSaleUnit(), defaultUnit));
                response.setSaleUnitConversionFactor(unitConversionFactor(product.getSaleUnit(), defaultUnit));
                if (response.getPurchaseUnitId() == null) {
                        response.setPurchaseUnitId(defaultUnit.getId());
                        response.setPurchaseUnitCode(defaultUnit.getCode());
                }
                if (response.getStockUnitId() == null) {
                        response.setStockUnitId(defaultUnit.getId());
                        response.setStockUnitCode(defaultUnit.getCode());
                }
                response.setStockUnitBaseGroup(unitBaseGroup(product.getStockUnit(), defaultUnit));
                response.setStockUnitConversionFactor(unitConversionFactor(product.getStockUnit(), defaultUnit));
                BigDecimal quantity = BigDecimal.ZERO;
                BigDecimal threshold = product.getLowStockThreshold();
                if (storeId != null) {
                        StockItem stockItem = stockItemRepository.findByProductIdAndStoreId(product.getId(), storeId).orElse(null);
                        quantity = stockItem != null ? stockItem.getQuantity() : BigDecimal.ZERO;
                        if (stockItem != null && stockItem.getLowStockThreshold() != null) {
                                threshold = stockItem.getLowStockThreshold();
                        }
                } else {
                        List<StockItem> stockItems = stockItemRepository.findAllByProductId(product.getId());
                        for (StockItem stockItem : stockItems) {
                                quantity = quantity.add(stockItem.getQuantity() == null ? BigDecimal.ZERO : stockItem.getQuantity());
                        }
                }
                response.setStock(quantity);
                BigDecimal availableSaleQty = convertStockToSaleQuantity(product, quantity)
                                .subtract(reservedSaleQty == null ? BigDecimal.ZERO : reservedSaleQty)
                                .max(BigDecimal.ZERO);
                response.setAvailableSaleQty(availableSaleQty);
                response.setLowStockThreshold(threshold);
                BigDecimal saleThreshold = convertStockToSaleQuantity(product, threshold == null ? BigDecimal.ZERO : threshold);
                response.setOutOfStock(product.isTrackInventory() && availableSaleQty.compareTo(BigDecimal.ZERO) <= 0);
                response.setLowStock(product.isTrackInventory() && availableSaleQty.compareTo(BigDecimal.ZERO) > 0
                                && availableSaleQty.compareTo(saleThreshold) <= 0);
                response.setParentProductId(product.getParentProduct() != null ? product.getParentProduct().getId() : null);
                response.setParentProductNameEn(product.getParentProduct() != null ? product.getParentProduct().getNameEn() : null);
                response.setVariantLabel(product.getVariantLabel());
                response.setBundleMode(product.getBundleMode());
                response.setResolvedPrice(resolvePrice(product));
                response.setBundleComponents(product.getBundleComponents().stream().map(component -> {
                        ProductDtos.ProductBundleComponentResponse componentResponse = new ProductDtos.ProductBundleComponentResponse();
                        componentResponse.setId(component.getId());
                        componentResponse.setComponentProductId(component.getComponentProduct().getId());
                        componentResponse.setComponentProductNameEn(component.getComponentProduct().getNameEn());
                        componentResponse.setComponentProductNameKm(component.getComponentProduct().getNameKm());
                        componentResponse.setComponentQuantity(component.getComponentQuantity());
                        return componentResponse;
                }).toList());
                return response;
        }

        private String unitBaseGroup(Unit configuredUnit, Unit fallbackUnit) {
                Unit unit = configuredUnit != null ? configuredUnit : fallbackUnit;
                return unit != null ? unit.getBaseUnitGroup() : null;
        }

        private BigDecimal unitConversionFactor(Unit configuredUnit, Unit fallbackUnit) {
                Unit unit = configuredUnit != null ? configuredUnit : fallbackUnit;
                if (unit == null || unit.getConversionFactor() == null || unit.getConversionFactor().compareTo(BigDecimal.ZERO) <= 0) {
                        return BigDecimal.ONE;
                }
                return unit.getConversionFactor();
        }

        private BigDecimal convertStockToSaleQuantity(Product product, BigDecimal stockQuantity) {
                BigDecimal safeStockQuantity = stockQuantity == null ? BigDecimal.ZERO : stockQuantity;
                Unit saleUnit = product.getSaleUnit();
                Unit stockUnit = product.getStockUnit();
                if (saleUnit == null || stockUnit == null) {
                        return safeStockQuantity;
                }
                if (saleUnit.getId() != null && saleUnit.getId().equals(stockUnit.getId())) {
                        return safeStockQuantity;
                }
                if (saleUnit.getBaseUnitGroup() == null || stockUnit.getBaseUnitGroup() == null
                                || !saleUnit.getBaseUnitGroup().equalsIgnoreCase(stockUnit.getBaseUnitGroup())) {
                        return safeStockQuantity;
                }
                BigDecimal saleFactor = unitConversionFactor(saleUnit, saleUnit);
                BigDecimal stockFactor = unitConversionFactor(stockUnit, stockUnit);
                if (saleFactor.compareTo(BigDecimal.ZERO) <= 0 || stockFactor.compareTo(BigDecimal.ZERO) <= 0) {
                        return safeStockQuantity;
                }
                return safeStockQuantity.multiply(stockFactor)
                                .divide(saleFactor, 3, java.math.RoundingMode.HALF_UP)
                                .stripTrailingZeros();
        }

        private Map<Long, BigDecimal> reservedSaleQtyMap(Long storeId, List<Product> products) {
                if (products == null || products.isEmpty()) {
                        return Map.of();
                }
                List<Long> productIds = products.stream()
                                .map(Product::getId)
                                .filter(Objects::nonNull)
                                .toList();
                if (productIds.isEmpty()) {
                        return Map.of();
                }
                Map<Long, BigDecimal> reservedQtyByProductId = new HashMap<>();
                saleRepository.findReservedQuantitiesByProductIds(productIds, storeId).forEach(view ->
                                reservedQtyByProductId.put(
                                                view.getProductId(),
                                                view.getReservedQty() == null ? BigDecimal.ZERO : view.getReservedQty()));
                return reservedQtyByProductId;
        }

        @Transactional(readOnly = true)
        public ProductDtos.ProductResponse getById(Long id) {
                Product product = productRepository.findById(id)
                                .orElseThrow(() -> new ApiException("Product not found"));
                return toProductResponse(product);
        }

        private BigDecimal resolvePrice(Product product) {
                for (PriceList priceList : priceListRepository.findEffectiveLists(java.time.Instant.now())) {
                        for (PriceListItem item : priceList.getItems()) {
                                if (Objects.equals(item.getProduct().getId(), product.getId())) {
                                        return item.getPrice();
                                }
                        }
                }
                return product.getPrice();
        }

        private static final class SeedPlan {
                private final List<String> categories;
                private final Map<String, String> categoryKmNames;
                private final List<SeedProduct> products;

                private SeedPlan(List<String> categories, Map<String, String> categoryKmNames,
                                List<SeedProduct> products) {
                        this.categories = categories;
                        this.categoryKmNames = categoryKmNames;
                        this.products = products;
                }

                private static SeedPlan coffeeShop() {
                        Map<String, String> categoryKm = new HashMap<>();
                        categoryKm.put("Coffee", "កាហ្វេ");
                        categoryKm.put("Tea & Coolers", "តែ និងភេសជ្ជៈត្រជាក់");
                        categoryKm.put("Pastries", "នំប៉័ង និងកុម្មង់");
                        categoryKm.put("Combos", "ឈុតកុម្ម៉ូ");
                        List<String> categories = List.of("Coffee", "Tea & Coolers", "Pastries", "Combos");
                        List<SeedProduct> products = new ArrayList<>();
                        products.add(new SeedProduct("CF-001", "880100001", "Americano", "អាមេរិកាណូ", "Coffee",
                                        new BigDecimal("2800"), new BigDecimal("6500")));
                        products.add(new SeedProduct("CF-002", "880100002", "Cafe Latte", "កាហ្វេឡាតេ", "Coffee",
                                        new BigDecimal("3400"), new BigDecimal("7500")));
                        products.add(new SeedProduct("CF-003", "880100003", "Caramel Frappe", "ហ្វ្រាប៉េការ៉ាមែល", "Coffee",
                                        new BigDecimal("4200"), new BigDecimal("9200")));
                        products.add(new SeedProduct("TC-001", "880100004", "Iced Lemon Tea", "តែលេមុនត្រជាក់", "Tea & Coolers",
                                        new BigDecimal("1800"), new BigDecimal("4500")));
                        products.add(new SeedProduct("TC-002", "880100005", "Lychee Soda", "សូដាលីជី", "Tea & Coolers",
                                        new BigDecimal("2100"), new BigDecimal("5000")));
                        products.add(new SeedProduct("PS-001", "880100006", "Butter Croissant", "ក្រូសង់ប៊ឺ", "Pastries",
                                        new BigDecimal("2200"), new BigDecimal("4800")));
                        products.add(new SeedProduct("PS-002", "880100007", "Blueberry Muffin", "មហ្វិនប៊្លូប៊ឺរី", "Pastries",
                                        new BigDecimal("2400"), new BigDecimal("5200")));
                        products.add(new SeedProduct("CB-001", "880100008", "Latte and Croissant Set", "ឡាតេ និងក្រូសង់", "Combos",
                                        new BigDecimal("5200"), new BigDecimal("11000")));
                        return new SeedPlan(categories, categoryKm, products);
                }

                private static SeedPlan restaurant() {
                        Map<String, String> categoryKm = new HashMap<>();
                        categoryKm.put("Starters", "ម្ហូបបើកឆាក");
                        categoryKm.put("Main Dishes", "ម្ហូបចម្បង");
                        categoryKm.put("Drinks", "ភេសជ្ជៈ");
                        categoryKm.put("Desserts", "បង្អែម");
                        List<String> categories = List.of("Starters", "Main Dishes", "Drinks", "Desserts");
                        List<SeedProduct> products = new ArrayList<>();
                        products.add(new SeedProduct("RS-ST-001", "880200001", "Fresh Spring Rolls", "ណែមស្រស់", "Starters",
                                        new BigDecimal("3500"), new BigDecimal("7000")));
                        products.add(new SeedProduct("RS-ST-002", "880200002", "Chicken Wings", "ស្លាបមាន់", "Starters",
                                        new BigDecimal("4200"), new BigDecimal("8500")));
                        products.add(new SeedProduct("RS-MD-001", "880200003", "Beef Lok Lak", "ឡុកឡាក់គោ", "Main Dishes",
                                        new BigDecimal("9000"), new BigDecimal("18000")));
                        products.add(new SeedProduct("RS-MD-002", "880200004", "Fried Rice Seafood", "បាយឆាសមុទ្រ", "Main Dishes",
                                        new BigDecimal("8500"), new BigDecimal("17000")));
                        products.add(new SeedProduct("RS-MD-003", "880200005", "Tom Yum Soup", "ស៊ុបទុំយាំ", "Main Dishes",
                                        new BigDecimal("7800"), new BigDecimal("15500")));
                        products.add(new SeedProduct("RS-DR-001", "880200006", "Fresh Orange Juice", "ទឹកក្រូចស្រស់", "Drinks",
                                        new BigDecimal("2800"), new BigDecimal("6000")));
                        products.add(new SeedProduct("RS-DS-001", "880200007", "Mango Sticky Rice", "បាយដំណើបស្វាយ", "Desserts",
                                        new BigDecimal("4200"), new BigDecimal("8000")));
                        products.add(new SeedProduct("RS-DS-002", "880200008", "Coconut Jelly", "ចាហួយដូង", "Desserts",
                                        new BigDecimal("1800"), new BigDecimal("4200")));
                        return new SeedPlan(categories, categoryKm, products);
                }

                private static SeedPlan mart() {
                        Map<String, String> categoryKm = new HashMap<>();
                        categoryKm.put("Packaged Foods", "អាហារវេចខ្ចប់");
                        categoryKm.put("Drinks", "ភេសជ្ជៈ");
                        categoryKm.put("Household", "សម្ភារៈប្រើប្រាស់");
                        categoryKm.put("Personal Care", "ថែទាំផ្ទាល់ខ្លួន");
                        List<String> categories = List.of("Packaged Foods", "Drinks", "Household", "Personal Care");
                        List<SeedProduct> products = new ArrayList<>();
                        products.add(new SeedProduct("MT-PF-001", "880300001", "Instant Noodles 6 Pack", "មីកញ្ចប់ ៦", "Packaged Foods",
                                        new BigDecimal("2800"), new BigDecimal("4200")));
                        products.add(new SeedProduct("MT-PF-002", "880300002", "Butter Crackers", "នំបុ័ងប្រៃ", "Packaged Foods",
                                        new BigDecimal("1500"), new BigDecimal("2600")));
                        products.add(new SeedProduct("MT-DR-001", "880300003", "Cola 1.5L", "កូកា ១.៥លីត្រ", "Drinks",
                                        new BigDecimal("3200"), new BigDecimal("4700")));
                        products.add(new SeedProduct("MT-DR-002", "880300004", "Energy Drink Can", "ភេសជ្ជៈកម្លាំង", "Drinks",
                                        new BigDecimal("1800"), new BigDecimal("2900")));
                        products.add(new SeedProduct("MT-HH-001", "880300005", "Dishwashing Liquid", "សាប៊ូលាងចាន", "Household",
                                        new BigDecimal("4200"), new BigDecimal("6500")));
                        products.add(new SeedProduct("MT-HH-002", "880300006", "Laundry Powder 900g", "ម្សៅបោកខោអាវ ៩០០ក្រាម", "Household",
                                        new BigDecimal("3900"), new BigDecimal("5900")));
                        products.add(new SeedProduct("MT-PC-001", "880300007", "Shampoo 340ml", "សាប៊ូកក់សក់ ៣៤០មល", "Personal Care",
                                        new BigDecimal("4600"), new BigDecimal("7200")));
                        products.add(new SeedProduct("MT-PC-002", "880300008", "Toothpaste Family Size", "ថ្នាំដុសធ្មេញគ្រួសារ", "Personal Care",
                                        new BigDecimal("2500"), new BigDecimal("3900")));
                        return new SeedPlan(categories, categoryKm, products);
                }

                private static SeedPlan bakery() {
                        Map<String, String> categoryKm = new HashMap<>();
                        categoryKm.put("Bread", "នំប៉័ង");
                        categoryKm.put("Pastries", "កុម្មង់");
                        categoryKm.put("Cakes", "នំខេក");
                        categoryKm.put("Ingredients", "គ្រឿងផ្សំ");
                        List<String> categories = List.of("Bread", "Pastries", "Cakes", "Ingredients");
                        List<SeedProduct> products = new ArrayList<>();
                        products.add(new SeedProduct("BK-BR-001", "880400001", "Milk Bread Loaf", "នំប៉័ងទឹកដោះគោ", "Bread",
                                        new BigDecimal("2800"), new BigDecimal("5500")));
                        products.add(new SeedProduct("BK-BR-002", "880400002", "Garlic Bread", "នំប៉័ងខ្ទឹម", "Bread",
                                        new BigDecimal("2400"), new BigDecimal("5000")));
                        products.add(new SeedProduct("BK-PS-001", "880400003", "Chocolate Danish", "ដាណឹសសូកូឡា", "Pastries",
                                        new BigDecimal("2600"), new BigDecimal("5200")));
                        products.add(new SeedProduct("BK-PS-002", "880400004", "Egg Tart", "តាតពងមាន់", "Pastries",
                                        new BigDecimal("2200"), new BigDecimal("4500")));
                        products.add(new SeedProduct("BK-CK-001", "880400005", "Vanilla Celebration Cake", "នំខេកវ៉ានីឡា", "Cakes",
                                        new BigDecimal("18000"), new BigDecimal("32000")));
                        products.add(new SeedProduct("BK-CK-002", "880400006", "Chocolate Roll Cake", "នំរូលសូកូឡា", "Cakes",
                                        new BigDecimal("9500"), new BigDecimal("18000")));
                        products.add(new SeedProduct("BK-IG-001", "880400007", "Bread Flour 25kg", "ម្សៅនំប៉័ង ២៥គក", "Ingredients",
                                        new BigDecimal("62000"), new BigDecimal("74000")));
                        products.add(new SeedProduct("BK-IG-002", "880400008", "Salted Butter Block", "ប៊ឺប្រៃ", "Ingredients",
                                        new BigDecimal("14500"), new BigDecimal("17800")));
                        return new SeedPlan(categories, categoryKm, products);
                }

                private static SeedPlan salon() {
                        Map<String, String> categoryKm = new HashMap<>();
                        categoryKm.put("Hair Services", "សេវាកម្មសក់");
                        categoryKm.put("Spa Services", "សេវាកម្មស្ប៉ា");
                        categoryKm.put("Retail Products", "ផលិតផលលក់រាយ");
                        categoryKm.put("Packages", "កញ្ចប់សេវាកម្ម");
                        List<String> categories = List.of("Hair Services", "Spa Services", "Retail Products", "Packages");
                        List<SeedProduct> products = new ArrayList<>();
                        products.add(new SeedProduct("SL-HS-001", "880500001", "Women Haircut", "កាត់សក់ស្ត្រី", "Hair Services",
                                        new BigDecimal("8000"), new BigDecimal("15000")));
                        products.add(new SeedProduct("SL-HS-002", "880500002", "Hair Color Service", "លាបពណ៌សក់", "Hair Services",
                                        new BigDecimal("18000"), new BigDecimal("38000")));
                        products.add(new SeedProduct("SL-SP-001", "880500003", "Foot Spa", "ស្ប៉ាជើង", "Spa Services",
                                        new BigDecimal("12000"), new BigDecimal("25000")));
                        products.add(new SeedProduct("SL-SP-002", "880500004", "Facial Treatment", "ថែរក្សាមុខ", "Spa Services",
                                        new BigDecimal("15000"), new BigDecimal("32000")));
                        products.add(new SeedProduct("SL-RP-001", "880500005", "Repair Shampoo", "សាប៊ូសក់ជួសជុល", "Retail Products",
                                        new BigDecimal("7200"), new BigDecimal("14000")));
                        products.add(new SeedProduct("SL-RP-002", "880500006", "Hair Serum", "សេរ៉ូមសក់", "Retail Products",
                                        new BigDecimal("6500"), new BigDecimal("13000")));
                        products.add(new SeedProduct("SL-PK-001", "880500007", "Haircut and Wash Package", "កញ្ចប់កាត់សក់និងលាង", "Packages",
                                        new BigDecimal("11000"), new BigDecimal("22000")));
                        products.add(new SeedProduct("SL-PK-002", "880500008", "Bridal Makeup Package", "កញ្ចប់តុបតែងមង្គលការ", "Packages",
                                        new BigDecimal("50000"), new BigDecimal("95000")));
                        return new SeedPlan(categories, categoryKm, products);
                }

                private static SeedPlan meatballRetail() {
                        Map<String, String> categoryKm = new HashMap<>();
                        categoryKm.put("Meatballs", "ប្រហិត");
                        categoryKm.put("Soup & Noodles", "ស៊ុប និងមី");
                        categoryKm.put("Drinks", "ភេសជ្ជៈ");
                        categoryKm.put("Combo Sets", "ឈុតកុម្ម៉ូ");
                        List<String> categories = List.of("Meatballs", "Soup & Noodles", "Drinks", "Combo Sets");
                        List<SeedProduct> products = new ArrayList<>();
                        products.add(new SeedProduct("MB-RTL-001", "886000001", "Fried Beef Meatball Stick", "ប្រហិតគោចៀន", "Meatballs",
                                        new BigDecimal("2500"), new BigDecimal("5000")));
                        products.add(new SeedProduct("MB-RTL-002", "886000002", "Cheese Meatball Stick", "ប្រហិតឈីស", "Meatballs",
                                        new BigDecimal("3000"), new BigDecimal("6000")));
                        products.add(new SeedProduct("MB-RTL-003", "886000003", "Spicy Fish Ball Cup", "ប្រហិតត្រីហឹរ", "Meatballs",
                                        new BigDecimal("2800"), new BigDecimal("5500")));
                        products.add(new SeedProduct("MB-SNP-001", "886000004", "Meatball Noodle Soup", "មីស៊ុបប្រហិត", "Soup & Noodles",
                                        new BigDecimal("5000"), new BigDecimal("10000")));
                        products.add(new SeedProduct("MB-SNP-002", "886000005", "Dry Noodles with Meatballs", "មីគោកប្រហិត", "Soup & Noodles",
                                        new BigDecimal("5200"), new BigDecimal("10500")));
                        products.add(new SeedProduct("MB-DRK-001", "886000006", "Iced Lemon Tea", "តែលេមុនត្រជាក់", "Drinks",
                                        new BigDecimal("1800"), new BigDecimal("4000")));
                        products.add(new SeedProduct("MB-DRK-002", "886000007", "Soy Milk", "ទឹកសណ្តែក", "Drinks",
                                        new BigDecimal("1500"), new BigDecimal("3500")));
                        products.add(new SeedProduct("MB-CMB-001", "886000008", "Snack Combo Set", "ឈុតប្រហិតសម្រន់", "Combo Sets",
                                        new BigDecimal("6500"), new BigDecimal("12000")));
                        return new SeedPlan(categories, categoryKm, products);
                }

                private static SeedPlan wholesale() {
                        Map<String, String> categoryKm = new HashMap<>();
                        categoryKm.put("Bulk Meatballs", "ប្រហិតដុំធំ");
                        categoryKm.put("Frozen Goods", "ទំនិញកក");
                        categoryKm.put("Packaging", "សម្ភារៈវេចខ្ចប់");
                        categoryKm.put("Distributor Packs", "កញ្ចប់ចែកចាយ");
                        List<String> categories = List.of("Bulk Meatballs", "Frozen Goods", "Packaging", "Distributor Packs");
                        List<SeedProduct> products = new ArrayList<>();
                        products.add(new SeedProduct("WS-BLK-001", "887000001", "Beef Meatball 5kg Box", "ប្រហិតគោ ៥គក", "Bulk Meatballs",
                                        new BigDecimal("65000"), new BigDecimal("85000")));
                        products.add(new SeedProduct("WS-BLK-002", "887000002", "Fish Ball 5kg Box", "ប្រហិតត្រី ៥គក", "Bulk Meatballs",
                                        new BigDecimal("58000"), new BigDecimal("76000")));
                        products.add(new SeedProduct("WS-FRZ-001", "887000003", "Frozen Meatball Pack 1kg", "ប្រហិតកក ១គក", "Frozen Goods",
                                        new BigDecimal("11000"), new BigDecimal("15000")));
                        products.add(new SeedProduct("WS-FRZ-002", "887000004", "Frozen Fish Ball Pack 1kg", "ប្រហិតត្រីកក ១គក", "Frozen Goods",
                                        new BigDecimal("9800"), new BigDecimal("13500")));
                        products.add(new SeedProduct("WS-PKG-001", "887000005", "Vacuum Bag 100pcs", "ថង់វ៉ាគ្យូម ១០០", "Packaging",
                                        new BigDecimal("12000"), new BigDecimal("16000")));
                        products.add(new SeedProduct("WS-PKG-002", "887000006", "Carton Box Small", "ប្រអប់កាតុងតូច", "Packaging",
                                        new BigDecimal("2500"), new BigDecimal("4000")));
                        products.add(new SeedProduct("WS-DST-001", "887000007", "Retailer Starter Pack", "កញ្ចប់ចាប់ផ្តើមអ្នកលក់", "Distributor Packs",
                                        new BigDecimal("90000"), new BigDecimal("120000")));
                        products.add(new SeedProduct("WS-DST-002", "887000008", "Wholesale Partner Pack", "កញ្ចប់ដៃគូលក់ដុំ", "Distributor Packs",
                                        new BigDecimal("140000"), new BigDecimal("185000")));
                        return new SeedPlan(categories, categoryKm, products);
                }

                private static SeedPlan production() {
                        Map<String, String> categoryKm = new HashMap<>();
                        categoryKm.put("Raw Materials", "វត្ថុធាតុដើម");
                        categoryKm.put("Seasonings & Mixes", "គ្រឿងផ្សំ និងលាយ");
                        categoryKm.put("Finished Goods", "ផលិតផលសម្រេច");
                        categoryKm.put("Packaging", "សម្ភារៈវេចខ្ចប់");
                        List<String> categories = List.of("Raw Materials", "Seasonings & Mixes", "Finished Goods", "Packaging");
                        List<SeedProduct> products = new ArrayList<>();
                        products.add(new SeedProduct("MB-RAW-001", "885100001", "Beef", "សាច់គោ", "Raw Materials",
                                        new BigDecimal("40000"), new BigDecimal("0"))
                                        .withFlags(false, true, true, "INGREDIENT")
                                        .withUnits("KG", "KG", "KG")
                                        .withLowStockThreshold("8")
                                        .withInitialStock("40"));
                        products.add(new SeedProduct("MB-RAW-002", "885100002", "Tapioca Starch", "ម្សៅតាព្យូកា", "Seasonings & Mixes",
                                        new BigDecimal("12000"), new BigDecimal("0"))
                                        .withFlags(false, true, true, "INGREDIENT")
                                        .withUnits("KG", "KG", "KG")
                                        .withLowStockThreshold("3")
                                        .withInitialStock("10"));
                        products.add(new SeedProduct("MB-RAW-003", "885100003", "Garlic", "ខ្ទឹម", "Seasonings & Mixes",
                                        new BigDecimal("9000"), new BigDecimal("0"))
                                        .withFlags(false, true, true, "INGREDIENT")
                                        .withUnits("KG", "KG", "KG")
                                        .withLowStockThreshold("1")
                                        .withInitialStock("5"));
                        products.add(new SeedProduct("MB-RAW-004", "885100004", "Sugar", "ស្ករ", "Seasonings & Mixes",
                                        new BigDecimal("5000"), new BigDecimal("0"))
                                        .withFlags(false, true, true, "INGREDIENT")
                                        .withUnits("KG", "KG", "KG")
                                        .withLowStockThreshold("1")
                                        .withInitialStock("4"));
                        products.add(new SeedProduct("MB-RAW-005", "885100005", "Salt", "អំបិល", "Seasonings & Mixes",
                                        new BigDecimal("3000"), new BigDecimal("0"))
                                        .withFlags(false, true, true, "INGREDIENT")
                                        .withUnits("KG", "KG", "KG")
                                        .withLowStockThreshold("1")
                                        .withInitialStock("3"));
                        products.add(new SeedProduct("MB-RAW-006", "885100006", "Black Pepper", "ម្រេចខ្មៅ", "Seasonings & Mixes",
                                        new BigDecimal("25000"), new BigDecimal("0"))
                                        .withFlags(false, true, true, "INGREDIENT")
                                        .withUnits("KG", "KG", "KG")
                                        .withLowStockThreshold("0.5")
                                        .withInitialStock("1"));
                        products.add(new SeedProduct("MB-RAW-007", "885100007", "Ice Water", "ទឹកកក", "Raw Materials",
                                        new BigDecimal("1200"), new BigDecimal("0"))
                                        .withFlags(false, true, true, "INGREDIENT")
                                        .withUnits("KG", "KG", "KG")
                                        .withLowStockThreshold("2")
                                        .withInitialStock("15"));
                        products.add(new SeedProduct("MB-PKG-001", "885100008", "1kg Clear Bag", "ថង់ថ្លា ១គក", "Packaging",
                                        new BigDecimal("350"), new BigDecimal("0"))
                                        .withFlags(false, true, true, "INGREDIENT")
                                        .withUnits("EACH", "EACH", "EACH")
                                        .withLowStockThreshold("50")
                                        .withInitialStock("300"));
                        products.add(new SeedProduct("MB-FIN-001", "885100009", "Beef Meatball 1kg Pack", "ប្រហិតសាច់គោ ១គក", "Finished Goods",
                                        new BigDecimal("14000"), new BigDecimal("18000"))
                                        .withFlags(true, false, true, "STOCK_ITEM")
                                        .withUnits("PACK", "PACK", "PACK")
                                        .withLowStockThreshold("10")
                                        .withInitialStock("0"));
                        return new SeedPlan(categories, categoryKm, products);
                }
        }

        private static final class SeedProduct {
                private final String sku;
                private final String barcode;
                private final String nameEn;
                private final String nameKm;
                private final String categoryNameEn;
                private final BigDecimal cost;
                private final BigDecimal price;
                private boolean sellable = true;
                private boolean purchasable = true;
                private boolean trackInventory = true;
                private String productType = "STOCK_ITEM";
                private BigDecimal lowStockThreshold = new BigDecimal("5.00");
                private String saleUnitCode = "EACH";
                private String purchaseUnitCode = "EACH";
                private String stockUnitCode = "EACH";
                private BigDecimal initialStock;

                private SeedProduct(String sku, String barcode, String nameEn, String nameKm, String categoryNameEn,
                                BigDecimal cost, BigDecimal price) {
                        this.sku = sku;
                        this.barcode = barcode;
                        this.nameEn = nameEn;
                        this.nameKm = nameKm;
                        this.categoryNameEn = categoryNameEn;
                        this.cost = cost;
                        this.price = price;
                }

                private SeedProduct withFlags(boolean sellable, boolean purchasable, boolean trackInventory, String productType) {
                        this.sellable = sellable;
                        this.purchasable = purchasable;
                        this.trackInventory = trackInventory;
                        this.productType = productType;
                        return this;
                }

                private SeedProduct withUnits(String saleUnitCode, String purchaseUnitCode, String stockUnitCode) {
                        this.saleUnitCode = saleUnitCode;
                        this.purchaseUnitCode = purchaseUnitCode;
                        this.stockUnitCode = stockUnitCode;
                        return this;
                }

                private SeedProduct withLowStockThreshold(String lowStockThreshold) {
                        this.lowStockThreshold = new BigDecimal(lowStockThreshold);
                        return this;
                }

                private SeedProduct withInitialStock(String initialStock) {
                        this.initialStock = new BigDecimal(initialStock);
                        return this;
                }
        }

        private void applyImages(Product product, ProductDtos.ProductRequest request) {
                product.getImages().clear();
                if (request.getImages() != null && !request.getImages().isEmpty()) {
                        for (ProductDtos.ProductImageRequest imageReq : request.getImages()) {
                                if (imageReq.getUrl() == null || imageReq.getUrl().isBlank())
                                        continue;
                                ProductImage image = new ProductImage();
                                image.setProduct(product);
                                image.setUrl(imageReq.getUrl());
                                image.setPrimaryImage(imageReq.isPrimary());
                                product.getImages().add(image);
                                if (imageReq.isPrimary()) {
                                        product.setImageUrl(imageReq.getUrl());
                                }
                        }
                        return;
                }

                if (request.getImageUrl() != null && !request.getImageUrl().isBlank()) {
                        ProductImage image = new ProductImage();
                        image.setProduct(product);
                        image.setUrl(request.getImageUrl());
                        image.setPrimaryImage(true);
                        product.getImages().add(image);
                }
        }
}
