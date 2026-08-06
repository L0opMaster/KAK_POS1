package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.ProductionOrder;
import com.kaknnea.pos.domain.ProductionOrderLine;
import com.kaknnea.pos.domain.ProductionRecipe;
import com.kaknnea.pos.domain.ProductionRecipeLine;
import com.kaknnea.pos.domain.StockItem;
import com.kaknnea.pos.domain.StockMovement;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.dto.ProductionDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.ProductionOrderRepository;
import com.kaknnea.pos.repository.ProductionRecipeRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.StockMovementRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.util.SecurityUtil;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.Year;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProductionService {
    private final ProductionRecipeRepository recipeRepository;
    private final ProductionOrderRepository orderRepository;
    private final ProductRepository productRepository;
    private final StoreRepository storeRepository;
    private final StockItemRepository stockItemRepository;
    private final StockMovementRepository stockMovementRepository;

    public ProductionService(
            ProductionRecipeRepository recipeRepository,
            ProductionOrderRepository orderRepository,
            ProductRepository productRepository,
            StoreRepository storeRepository,
            StockItemRepository stockItemRepository,
            StockMovementRepository stockMovementRepository) {
        this.recipeRepository = recipeRepository;
        this.orderRepository = orderRepository;
        this.productRepository = productRepository;
        this.storeRepository = storeRepository;
        this.stockItemRepository = stockItemRepository;
        this.stockMovementRepository = stockMovementRepository;
    }

    // -------------------------------------------------------------------------
    // Recipes
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public List<ProductionDtos.RecipeResponse> listRecipes() {
        return recipeRepository.findAll().stream().map(this::toRecipeResponse).toList();
    }

    @Transactional
    public ProductionDtos.RecipeResponse createRecipe(ProductionDtos.RecipeRequest request) {
        ProductionRecipe recipe = new ProductionRecipe();
        applyRecipeCreate(recipe, request);
        return toRecipeResponse(recipeRepository.save(recipe));
    }

    @Transactional
    public ProductionDtos.RecipeResponse updateRecipe(Long id, ProductionDtos.RecipeUpdateRequest request) {
        ProductionRecipe recipe = recipeRepository.findById(id)
                .orElseThrow(() -> new ApiException("Production recipe not found"));
        recipe.setName(request.getName().trim());
        recipe.setOutputQuantity(request.getOutputQuantity());
        recipe.setActive(request.isActive());
        recipe.setNotes(request.getNotes());
        recipe.getLines().clear();
        recipeRepository.save(recipe); // flush clear before rebuilding lines
        for (ProductionDtos.RecipeLineRequest lineRequest : request.getLines()) {
            Product component = productRepository.findById(lineRequest.getComponentProductId())
                    .orElseThrow(() -> new ApiException("Component product not found"));
            if (!component.isTrackInventory()) {
                throw new ApiException(component.getNameEn() + " must track inventory");
            }
            ProductionRecipeLine line = new ProductionRecipeLine();
            line.setRecipe(recipe);
            line.setComponentProduct(component);
            line.setComponentQuantity(lineRequest.getComponentQuantity());
            recipe.getLines().add(line);
        }
        return toRecipeResponse(recipeRepository.save(recipe));
    }

    @Transactional
    public void deactivateRecipe(Long id) {
        ProductionRecipe recipe = recipeRepository.findById(id)
                .orElseThrow(() -> new ApiException("Production recipe not found"));
        recipe.setActive(false);
        recipeRepository.save(recipe);
    }

    // -------------------------------------------------------------------------
    // Availability check
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public ProductionDtos.AvailabilityCheckResponse checkAvailability(
            ProductionDtos.AvailabilityCheckRequest request) {
        ProductionRecipe recipe = recipeRepository.findById(request.getRecipeId())
                .orElseThrow(() -> new ApiException("Production recipe not found"));
        BigDecimal baseOutput = recipe.getOutputQuantity();
        if (baseOutput == null || baseOutput.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("Recipe output quantity must be greater than zero");
        }
        BigDecimal ratio = request.getProducedQuantity().divide(baseOutput, 6, RoundingMode.HALF_UP);

        List<ProductionDtos.AvailabilityCheckResponse.ComponentAvailability> components = new ArrayList<>();
        boolean allSufficient = true;

        for (ProductionRecipeLine recipeLine : recipe.getLines()) {
            BigDecimal required = recipeLine.getComponentQuantity()
                    .multiply(ratio).setScale(4, RoundingMode.HALF_UP);
            BigDecimal onHand = stockItemRepository
                    .findByProductIdAndStoreId(recipeLine.getComponentProduct().getId(), request.getStoreId())
                    .map(StockItem::getQuantity)
                    .orElse(BigDecimal.ZERO);
            boolean sufficient = onHand.compareTo(required) >= 0;
            if (!sufficient)
                allSufficient = false;

            ProductionDtos.AvailabilityCheckResponse.ComponentAvailability ca =
                    new ProductionDtos.AvailabilityCheckResponse.ComponentAvailability();
            ca.setProductId(recipeLine.getComponentProduct().getId());
            ca.setProductNameEn(recipeLine.getComponentProduct().getNameEn());
            ca.setStockUnitCode(recipeLine.getComponentProduct().getStockUnit() != null
                    ? recipeLine.getComponentProduct().getStockUnit().getCode()
                    : null);
            ca.setRequired(required);
            ca.setOnHand(onHand);
            ca.setSufficient(sufficient);
            components.add(ca);
        }

        ProductionDtos.AvailabilityCheckResponse response = new ProductionDtos.AvailabilityCheckResponse();
        response.setAvailable(allSufficient);
        response.setComponents(components);
        return response;
    }

    // -------------------------------------------------------------------------
    // Production orders — 4-stage workflow
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public List<ProductionDtos.ProductionOrderResponse> listOrders() {
        return orderRepository.findAll().stream().map(this::toOrderResponse).toList();
    }

    /** Stage 1: Create a DRAFT order — no stock touched. */
    @Transactional
    public ProductionDtos.ProductionOrderResponse createOrder(ProductionDtos.ProductionOrderRequest request) {
        ProductionRecipe recipe = recipeRepository.findById(request.getRecipeId())
                .orElseThrow(() -> new ApiException("Production recipe not found"));
        Store store = storeRepository.findById(request.getStoreId() == null ? 1L : request.getStoreId())
                .orElseThrow(() -> new ApiException("Store not found"));
        BigDecimal baseOutput = recipe.getOutputQuantity();
        if (baseOutput == null || baseOutput.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("Recipe output quantity must be greater than zero");
        }

        ProductionOrder order = new ProductionOrder();
        order.setRecipe(recipe);
        order.setStore(store);
        order.setStatus("DRAFT");
        order.setPlannedQuantity(request.getPlannedQuantity());
        order.setProducedQuantity(BigDecimal.ZERO);
        order.setWasteQuantity(BigDecimal.ZERO);
        order.setNotes(request.getNotes());
        order.setCreatedBy(SecurityUtil.currentUsername());
        order.setLines(new ArrayList<>());

        BigDecimal ratio = request.getPlannedQuantity().divide(baseOutput, 6, RoundingMode.HALF_UP);
        for (ProductionRecipeLine recipeLine : recipe.getLines()) {
            BigDecimal plannedQty = recipeLine.getComponentQuantity()
                    .multiply(ratio).setScale(2, RoundingMode.HALF_UP);
            ProductionOrderLine line = new ProductionOrderLine();
            line.setProductionOrder(order);
            line.setComponentProduct(recipeLine.getComponentProduct());
            line.setPlannedQuantity(plannedQty);
            line.setConsumedQuantity(BigDecimal.ZERO); // not consumed yet
            order.getLines().add(line);
        }

        ProductionOrder saved = orderRepository.save(order);
        assignOrderNumber(saved);
        return toOrderResponse(saved);
    }

    /** Stage 2: Start the order — DRAFT → IN_PROGRESS, deduct component stock. */
    @Transactional
    public ProductionDtos.ProductionOrderResponse startOrder(Long id) {
        ProductionOrder order = orderRepository.findById(id)
                .orElseThrow(() -> new ApiException("Production order not found"));
        if (!"DRAFT".equals(order.getStatus())) {
            throw new ApiException("Only DRAFT orders can be started");
        }
        Store store = order.getStore();
        ProductionRecipe recipe = order.getRecipe();
        BigDecimal baseOutput = recipe.getOutputQuantity();
        BigDecimal ratio = order.getPlannedQuantity().divide(baseOutput, 6, RoundingMode.HALF_UP);

        for (ProductionOrderLine line : order.getLines()) {
            Product component = line.getComponentProduct();
            BigDecimal consumedQty = line.getPlannedQuantity(); // use planned as consumed on start
            StockItem stockItem = stockItemRepository
                    .findByProductIdAndStoreId(component.getId(), store.getId())
                    .orElseGet(() -> {
                        StockItem s = new StockItem();
                        s.setProduct(component);
                        s.setStore(store);
                        s.setQuantity(BigDecimal.ZERO);
                        s.setLowStockThreshold(component.getLowStockThreshold());
                        return stockItemRepository.save(s);
                    });
            if (stockItem.getQuantity().compareTo(consumedQty) < 0) {
                throw new ApiException("Insufficient stock for " + component.getNameEn()
                        + " (need " + consumedQty.stripTrailingZeros().toPlainString()
                        + ", have " + stockItem.getQuantity().stripTrailingZeros().toPlainString() + ")");
            }
            stockItem.setQuantity(stockItem.getQuantity().subtract(consumedQty));
            stockItemRepository.save(stockItem);
            postMovement(store, component, consumedQty.negate(),
                    "PRODUCTION_OUT", "Production start: " + recipe.getName());
            line.setConsumedQuantity(consumedQty);
        }

        order.setStatus("IN_PROGRESS");
        order.setStartedAt(Instant.now());
        order.setPostedAt(Instant.now()); // backward compat
        return toOrderResponse(orderRepository.save(order));
    }

    /** Stage 3: Complete the order — IN_PROGRESS → COMPLETED, add output to stock. */
    @Transactional
    public ProductionDtos.ProductionOrderResponse completeOrder(Long id,
            ProductionDtos.CompleteOrderRequest request) {
        ProductionOrder order = orderRepository.findById(id)
                .orElseThrow(() -> new ApiException("Production order not found"));
        if (!"IN_PROGRESS".equals(order.getStatus())) {
            throw new ApiException("Only IN_PROGRESS orders can be completed");
        }
        if (request.getProducedQuantity().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("Produced quantity must be greater than zero");
        }

        Store store = order.getStore();
        ProductionRecipe recipe = order.getRecipe();
        BigDecimal producedQty = request.getProducedQuantity();
        BigDecimal wasteQty = request.getWasteQuantity() == null ? BigDecimal.ZERO : request.getWasteQuantity();

        order.setProducedQuantity(producedQty);
        order.setWasteQuantity(wasteQty);
        if (request.getNotes() != null && !request.getNotes().isBlank()) {
            order.setNotes(request.getNotes());
        }

        // Add produced output to stock
        Product outputProduct = recipe.getOutputProduct();
        StockItem outputStock = stockItemRepository
                .findByProductIdAndStoreId(outputProduct.getId(), store.getId())
                .orElseGet(() -> {
                    StockItem item = new StockItem();
                    item.setProduct(outputProduct);
                    item.setStore(store);
                    item.setQuantity(BigDecimal.ZERO);
                    item.setLowStockThreshold(outputProduct.getLowStockThreshold());
                    return item;
                });
        outputStock.setQuantity(outputStock.getQuantity().add(producedQty));
        outputStock.setLowStockThreshold(outputProduct.getLowStockThreshold());
        stockItemRepository.save(outputStock);
        postMovement(store, outputProduct, producedQty,
                "PRODUCTION_IN", "Production output: " + recipe.getName());

        if (wasteQty.compareTo(BigDecimal.ZERO) > 0) {
            postMovement(store, outputProduct, wasteQty.negate(),
                    "WASTE", "Production waste: " + recipe.getName());
        }

        order.setStatus("COMPLETED");
        order.setCompletedAt(Instant.now());
        return toOrderResponse(orderRepository.save(order));
    }

    /** Stage 4: Cancel the order — DRAFT or IN_PROGRESS → CANCELLED, reverse stock if needed. */
    @Transactional
    public ProductionDtos.ProductionOrderResponse cancelOrder(Long id,
            ProductionDtos.CancelOrderRequest request) {
        ProductionOrder order = orderRepository.findById(id)
                .orElseThrow(() -> new ApiException("Production order not found"));
        if (!"DRAFT".equals(order.getStatus()) && !"IN_PROGRESS".equals(order.getStatus())) {
            throw new ApiException("Only DRAFT or IN_PROGRESS orders can be cancelled");
        }

        Store store = order.getStore();
        ProductionRecipe recipe = order.getRecipe();

        if ("IN_PROGRESS".equals(order.getStatus())) {
            // Reverse component deductions
            for (ProductionOrderLine line : order.getLines()) {
                BigDecimal consumed = line.getConsumedQuantity();
                if (consumed == null || consumed.compareTo(BigDecimal.ZERO) <= 0) continue;
                StockItem stockItem = stockItemRepository
                        .findByProductIdAndStoreId(line.getComponentProduct().getId(), store.getId())
                        .orElseGet(() -> {
                            StockItem item = new StockItem();
                            item.setProduct(line.getComponentProduct());
                            item.setStore(store);
                            item.setQuantity(BigDecimal.ZERO);
                            item.setLowStockThreshold(line.getComponentProduct().getLowStockThreshold());
                            return item;
                        });
                stockItem.setQuantity(stockItem.getQuantity().add(consumed));
                stockItemRepository.save(stockItem);
                postMovement(store, line.getComponentProduct(), consumed,
                        "PRODUCTION_CANCEL", "Production cancelled: " + recipe.getName());
            }
        }

        order.setStatus("CANCELLED");
        order.setCancelledAt(Instant.now());
        order.setCancelReason(request != null && request.getReason() != null ? request.getReason().trim() : null);
        return toOrderResponse(orderRepository.save(order));
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    private void assignOrderNumber(ProductionOrder order) {
        if (order.getOrderNumber() == null) {
            order.setOrderNumber(
                    String.format("MO-%d-%04d", Year.now().getValue(), order.getId()));
            orderRepository.save(order);
        }
    }

    private void applyRecipeCreate(ProductionRecipe recipe, ProductionDtos.RecipeRequest request) {
        Product outputProduct = productRepository.findById(request.getOutputProductId())
                .orElseThrow(() -> new ApiException("Output product not found"));
        if (!outputProduct.isTrackInventory()) {
            throw new ApiException("Output product must track inventory");
        }
        recipe.setName(request.getName().trim());
        recipe.setOutputProduct(outputProduct);
        recipe.setOutputQuantity(request.getOutputQuantity());
        recipe.setActive(request.isActive());
        recipe.setNotes(request.getNotes());
        if (recipe.getLines() == null)
            recipe.setLines(new ArrayList<>());
        recipe.getLines().clear();
        for (ProductionDtos.RecipeLineRequest lineRequest : request.getLines()) {
            Product component = productRepository.findById(lineRequest.getComponentProductId())
                    .orElseThrow(() -> new ApiException("Component product not found"));
            if (!component.isTrackInventory()) {
                throw new ApiException(component.getNameEn() + " must track inventory");
            }
            ProductionRecipeLine line = new ProductionRecipeLine();
            line.setRecipe(recipe);
            line.setComponentProduct(component);
            line.setComponentQuantity(lineRequest.getComponentQuantity());
            recipe.getLines().add(line);
        }
    }

    private void postMovement(Store store, Product product, BigDecimal quantity,
            String type, String reason) {
        StockMovement movement = new StockMovement();
        movement.setStore(store);
        movement.setProduct(product);
        movement.setQuantity(quantity);
        movement.setMovementType(type);
        movement.setReason(reason);
        movement.setCreatedBy(SecurityUtil.currentUsername());
        stockMovementRepository.save(movement);
    }

    // -------------------------------------------------------------------------
    // Mappers
    // -------------------------------------------------------------------------

    private ProductionDtos.RecipeResponse toRecipeResponse(ProductionRecipe recipe) {
        ProductionDtos.RecipeResponse response = new ProductionDtos.RecipeResponse();
        response.setId(recipe.getId());
        response.setName(recipe.getName());
        response.setOutputProductId(recipe.getOutputProduct().getId());
        response.setOutputProductNameEn(recipe.getOutputProduct().getNameEn());
        response.setOutputQuantity(recipe.getOutputQuantity());
        response.setActive(recipe.isActive());
        response.setNotes(recipe.getNotes());
        response.setLines(recipe.getLines().stream().map(line -> {
            ProductionDtos.RecipeLineResponse lr = new ProductionDtos.RecipeLineResponse();
            lr.setId(line.getId());
            lr.setComponentProductId(line.getComponentProduct().getId());
            lr.setComponentProductNameEn(line.getComponentProduct().getNameEn());
            lr.setComponentQuantity(line.getComponentQuantity());
            lr.setComponentStockUnitCode(line.getComponentProduct().getStockUnit() != null
                    ? line.getComponentProduct().getStockUnit().getCode()
                    : null);
            return lr;
        }).toList());
        return response;
    }

    private ProductionDtos.ProductionOrderResponse toOrderResponse(ProductionOrder order) {
        ProductionDtos.ProductionOrderResponse response = new ProductionDtos.ProductionOrderResponse();
        response.setId(order.getId());
        response.setOrderNumber(order.getOrderNumber());
        response.setRecipeId(order.getRecipe().getId());
        response.setRecipeName(order.getRecipe().getName());
        response.setStoreId(order.getStore().getId());
        response.setStoreName(order.getStore().getName());
        response.setStatus(order.getStatus());
        response.setPlannedQuantity(order.getPlannedQuantity());
        response.setProducedQuantity(order.getProducedQuantity());
        response.setWasteQuantity(order.getWasteQuantity());
        response.setPostedAt(order.getPostedAt() == null ? null : order.getPostedAt().toString());
        response.setStartedAt(order.getStartedAt() == null ? null : order.getStartedAt().toString());
        response.setCompletedAt(order.getCompletedAt() == null ? null : order.getCompletedAt().toString());
        response.setCancelledAt(order.getCancelledAt() == null ? null : order.getCancelledAt().toString());
        response.setCancelReason(order.getCancelReason());
        response.setNotes(order.getNotes());
        response.setCreatedBy(order.getCreatedBy());
        BigDecimal planned = order.getPlannedQuantity();
        BigDecimal produced = order.getProducedQuantity();
        if (planned != null && planned.compareTo(BigDecimal.ZERO) > 0
                && produced != null && produced.compareTo(BigDecimal.ZERO) > 0) {
            response.setYieldPercent(produced
                    .divide(planned, 4, RoundingMode.HALF_UP)
                    .multiply(new BigDecimal("100"))
                    .doubleValue());
        }
        response.setLines(order.getLines().stream().map(line -> {
            ProductionDtos.ProductionOrderLineResponse lr = new ProductionDtos.ProductionOrderLineResponse();
            lr.setId(line.getId());
            lr.setComponentProductId(line.getComponentProduct().getId());
            lr.setComponentProductNameEn(line.getComponentProduct().getNameEn());
            lr.setPlannedQuantity(line.getPlannedQuantity());
            lr.setConsumedQuantity(line.getConsumedQuantity());
            return lr;
        }).toList());
        return response;
    }
}
