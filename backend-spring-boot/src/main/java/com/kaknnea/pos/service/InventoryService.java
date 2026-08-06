package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.StockItem;
import com.kaknnea.pos.domain.StockMovement;
import com.kaknnea.pos.domain.InventorySnapshot;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.dto.InventoryDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.InventorySnapshotRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.StockMovementRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.RoleUtil;
import com.kaknnea.pos.util.SecurityUtil;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class InventoryService {
    private final StockItemRepository stockItemRepository;
    private final StockMovementRepository stockMovementRepository;
    private final ProductRepository productRepository;
    private final StoreRepository storeRepository;
    private final AuditService auditService;
    private final UserRepository userRepository;
    private final InventorySnapshotRepository inventorySnapshotRepository;

    public InventoryService(StockItemRepository stockItemRepository,
            StockMovementRepository stockMovementRepository,
            ProductRepository productRepository,
            StoreRepository storeRepository,
            AuditService auditService,
            UserRepository userRepository,
            InventorySnapshotRepository inventorySnapshotRepository) {
        this.stockItemRepository = stockItemRepository;
        this.stockMovementRepository = stockMovementRepository;
        this.productRepository = productRepository;
        this.storeRepository = storeRepository;
        this.auditService = auditService;
        this.userRepository = userRepository;
        this.inventorySnapshotRepository = inventorySnapshotRepository;
    }

    @Transactional(readOnly = true)
    public List<InventoryDtos.StockResponse> listStocks(Long storeId) {
        return resolveStockItems(storeId).stream().map(this::toStockResponse).collect(Collectors.toList());
    }

    @Transactional
    public InventoryDtos.StockResponse stockIn(InventoryDtos.StockInRequest request) {
        Product product = productRepository.findById(request.getProductId())
                .orElseThrow(() -> new ApiException("Product not found"));
        if (!product.isTrackInventory()) {
            throw new ApiException("Product is not inventory tracked");
        }
        Store store = resolveStore(request.getStoreId());
        StockItem item = stockItemRepository.findByProductIdAndStoreId(product.getId(), store.getId())
                .orElseGet(() -> {
                    StockItem s = new StockItem();
                    s.setProduct(product);
                    s.setStore(store);
                    s.setQuantity(BigDecimal.ZERO);
                    s.setLowStockThreshold(product.getLowStockThreshold());
                    return s;
                });
        item.setQuantity(item.getQuantity().add(request.getQuantity()));
        StockItem saved = stockItemRepository.save(item);
        StockMovement movement = new StockMovement();
        movement.setProduct(product);
        movement.setStore(store);
        movement.setMovementType("STOCK_IN");
        movement.setQuantity(request.getQuantity());
        movement.setReason(request.getReason());
        movement.setCreatedBy(SecurityUtil.currentUsername());
        stockMovementRepository.save(movement);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        if (actor != null) {
            auditService.log(actor, "STOCK_IN", "StockItem", String.valueOf(saved.getId()), null, saved);
        }
        return toStockResponse(saved);
    }

    @Transactional
    public InventoryDtos.StockResponse adjust(InventoryDtos.StockAdjustRequest request) {
        Product product = productRepository.findById(request.getProductId())
                .orElseThrow(() -> new ApiException("Product not found"));
        if (!product.isTrackInventory()) {
            throw new ApiException("Product is not inventory tracked");
        }
        Store store = resolveStore(request.getStoreId());
        StockItem item = stockItemRepository.findByProductIdAndStoreId(product.getId(), store.getId())
                .orElseGet(() -> {
                    StockItem s = new StockItem();
                    s.setProduct(product);
                    s.setStore(store);
                    s.setQuantity(BigDecimal.ZERO);
                    s.setLowStockThreshold(product.getLowStockThreshold());
                    return s;
                });
        BigDecimal newQty = item.getQuantity().add(request.getQuantity());
        if (newQty.compareTo(BigDecimal.ZERO) < 0 && !(RoleUtil.hasRole("OWNER") || RoleUtil.hasRole("MANAGER"))) {
            throw new ApiException("Negative stock not allowed");
        }
        item.setQuantity(newQty);
        StockItem saved = stockItemRepository.save(item);
        StockMovement movement = new StockMovement();
        movement.setProduct(product);
        movement.setStore(store);
        movement.setMovementType("ADJUSTMENT");
        movement.setQuantity(request.getQuantity());
        movement.setReason(request.getReason());
        movement.setCreatedBy(SecurityUtil.currentUsername());
        stockMovementRepository.save(movement);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        if (actor != null) {
            auditService.log(actor, "STOCK_ADJUST", "StockItem", String.valueOf(saved.getId()), null, saved);
        }
        return toStockResponse(saved);
    }

    @Transactional(readOnly = true)
    public InventoryDtos.StockValuationResponse valuation(Long storeId) {
        // Use StockItem entities directly to avoid an N+1 re-fetch of Product per item
        List<StockItem> stockItems = resolveStockItems(storeId);
        BigDecimal total = stockItems.stream()
                .map(item -> {
                    BigDecimal cost = item.getProduct().getCost();
                    if (cost == null) return BigDecimal.ZERO;
                    return cost.multiply(item.getQuantity());
                })
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        List<InventoryDtos.StockResponse> items = stockItems.stream()
                .map(this::toStockResponse).collect(Collectors.toList());
        InventoryDtos.StockValuationResponse resp = new InventoryDtos.StockValuationResponse();
        resp.setItems(items);
        resp.setTotalValue(total);
        resp.setValuedAt(Instant.now().toString());
        return resp;
    }

    @Transactional(readOnly = true)
    public List<InventoryDtos.StockMovementResponse> movements(Long storeId) {
        // Cap at 500 most-recent movements to prevent full-table load; callers should paginate
        List<StockMovement> source = storeId != null
                ? stockMovementRepository.findAllByStoreIdOrderByCreatedAtDesc(storeId)
                : stockMovementRepository.findTop500ByOrderByCreatedAtDesc();
        return source.stream().map(m -> {
            InventoryDtos.StockMovementResponse resp = new InventoryDtos.StockMovementResponse();
            resp.setId(m.getId());
            resp.setProductId(m.getProduct().getId());
            resp.setProductNameEn(m.getProduct().getNameEn());
            resp.setStoreName(m.getStore() != null ? m.getStore().getName() : null);
            resp.setStoreId(m.getStore() != null ? m.getStore().getId() : null);
            resp.setMovementType(normalizeMovementType(m.getMovementType()));
            resp.setQuantity(m.getQuantity());
            resp.setReason(m.getReason());
            resp.setCreatedBy(m.getCreatedBy());
            resp.setCreatedAt(m.getCreatedAt());
            return resp;
        }).collect(Collectors.toList());
    }

    private InventoryDtos.StockResponse toStockResponse(StockItem item) {
        InventoryDtos.StockResponse resp = new InventoryDtos.StockResponse();
        resp.setId(item.getId());
        resp.setProductId(item.getProduct().getId());
        resp.setProductNameEn(item.getProduct().getNameEn());
        resp.setProductNameKm(item.getProduct().getNameKm());
        resp.setProductCode(item.getProduct().getSku());
        resp.setQuantity(item.getQuantity());
        resp.setLowStockThreshold(item.getLowStockThreshold());
        BigDecimal unitCost = item.getProduct().getCost() == null ? BigDecimal.ZERO : item.getProduct().getCost();
        resp.setUnitCost(unitCost);
        resp.setTotalValue(unitCost.multiply(item.getQuantity() == null ? BigDecimal.ZERO : item.getQuantity()));
        resp.setStoreId(item.getStore().getId());
        resp.setStoreName(item.getStore().getName());
        resp.setUpdatedAt(item.getUpdatedAt());
        resp.setStockUnitCode(
                item.getProduct().getStockUnit() != null ? item.getProduct().getStockUnit().getCode() : "EACH");
        return resp;
    }

    @Transactional(readOnly = true)
    public List<InventoryDtos.InventoryCountEntryResponse> listCountEntries(java.time.LocalDate snapshotDate,
            Long storeId) {
        return inventorySnapshotRepository
                .findAllBySnapshotDateAndStoreIdOrderByProduct_NameEnAsc(snapshotDate, storeId)
                .stream()
                .map(snapshot -> {
                    InventoryDtos.InventoryCountEntryResponse response = new InventoryDtos.InventoryCountEntryResponse();
                    response.setSnapshotId(snapshot.getId());
                    response.setProductId(snapshot.getProduct().getId());
                    response.setProductNameEn(snapshot.getProduct().getNameEn());
                    response.setProductNameKm(snapshot.getProduct().getNameKm());
                    response.setExpectedQuantity(snapshot.getQuantity());
                    response.setCountedQuantity(snapshot.getCountedQuantity());
                    response.setVarianceQuantity(snapshot.getVarianceQuantity());
                    response.setCountStatus(snapshot.getCountStatus());
                    response.setNotes(snapshot.getNotes());
                    return response;
                })
                .toList();
    }

    @Transactional
    public InventoryDtos.InventoryCountEntryResponse recordCount(InventoryDtos.InventoryCountEntryRequest request) {
        InventorySnapshot snapshot = inventorySnapshotRepository.findById(request.getSnapshotId())
                .orElseThrow(() -> new ApiException("Inventory snapshot not found"));
        snapshot.setCountedQuantity(request.getCountedQuantity());
        snapshot.setVarianceQuantity(request.getCountedQuantity().subtract(snapshot.getQuantity()));
        snapshot.setCountStatus("COUNTED");
        snapshot.setNotes(request.getNotes());
        InventorySnapshot saved = inventorySnapshotRepository.save(snapshot);
        InventoryDtos.InventoryCountEntryResponse response = new InventoryDtos.InventoryCountEntryResponse();
        response.setSnapshotId(saved.getId());
        response.setProductId(saved.getProduct().getId());
        response.setProductNameEn(saved.getProduct().getNameEn());
        response.setProductNameKm(saved.getProduct().getNameKm());
        response.setExpectedQuantity(saved.getQuantity());
        response.setCountedQuantity(saved.getCountedQuantity());
        response.setVarianceQuantity(saved.getVarianceQuantity());
        response.setCountStatus(saved.getCountStatus());
        response.setNotes(saved.getNotes());
        return response;
    }

    @Transactional
    public InventoryDtos.InventoryCountPostResponse postCount(InventoryDtos.InventoryCountPostRequest request) {
        Store store = storeRepository.findById(request.getStoreId())
                .orElseThrow(() -> new ApiException("Store not found"));
        List<InventorySnapshot> snapshots = inventorySnapshotRepository
                .findAllBySnapshotDateAndStoreIdOrderByProduct_NameEnAsc(request.getSnapshotDate(),
                        request.getStoreId());
        int itemsPosted = 0;
        int variancesApplied = 0;
        for (InventorySnapshot snapshot : snapshots) {
            if (snapshot.getCountedQuantity() == null || snapshot.getPostedAt() != null) {
                continue;
            }
            StockItem stockItem = stockItemRepository
                    .findByProductIdAndStoreId(snapshot.getProduct().getId(), request.getStoreId())
                    .orElseThrow(() -> new ApiException("Stock item not found for counted product"));
            BigDecimal variance = snapshot.getCountedQuantity().subtract(stockItem.getQuantity());
            stockItem.setQuantity(snapshot.getCountedQuantity());
            stockItemRepository.save(stockItem);

            StockMovement movement = new StockMovement();
            movement.setProduct(snapshot.getProduct());
            movement.setStore(store);
            movement.setMovementType("COUNT");
            movement.setQuantity(variance);
            movement.setReason(snapshot.getNotes() == null || snapshot.getNotes().isBlank() ? "Inventory count"
                    : snapshot.getNotes());
            movement.setCreatedBy(SecurityUtil.currentUsername());
            stockMovementRepository.save(movement);

            snapshot.setVarianceQuantity(variance);
            snapshot.setCountStatus("POSTED");
            snapshot.setPostedAt(Instant.now());
            inventorySnapshotRepository.save(snapshot);

            itemsPosted++;
            if (variance.compareTo(BigDecimal.ZERO) != 0) {
                variancesApplied++;
            }
        }
        InventoryDtos.InventoryCountPostResponse result = new InventoryDtos.InventoryCountPostResponse();
        result.setItemsPosted(itemsPosted);
        result.setVariancesApplied(variancesApplied);
        result.setSnapshotDate(request.getSnapshotDate().toString());
        result.setStoreId(request.getStoreId());
        return result;
    }

    private List<StockItem> resolveStockItems(Long storeId) {
        return storeId == null ? stockItemRepository.findAll() : stockItemRepository.findAllByStoreId(storeId);
    }

    private Store resolveStore(Long storeId) {
        if (storeId == null) {
            return storeRepository.findAll().stream()
                    .findFirst()
                    .orElseThrow(() -> new ApiException("Store not found"));
        }
        return storeRepository.findById(storeId)
                .orElseThrow(() -> new ApiException("Store not found"));
    }

    private String normalizeMovementType(String movementType) {
        if (movementType == null) {
            return "";
        }
        // Normalise legacy aliases written by older code paths
        return switch (movementType) {
            case "IN"              -> "STOCK_IN";
            case "ADJUST"         -> "ADJUSTMENT";
            case "PURCHASE"       -> "STOCK_IN";       // legacy PurchaseService.receive()
            // The following are already canonical — listed here for documentation only
            case "STOCK_IN"       -> "STOCK_IN";
            case "ADJUSTMENT"     -> "ADJUSTMENT";
            case "SALE"           -> "SALE";
            case "RETURN"         -> "RETURN";
            case "GRN"            -> "GRN";
            case "PURCHASE_RETURN"-> "PURCHASE_RETURN";
            case "TRANSFER_IN"    -> "TRANSFER_IN";
            case "TRANSFER_OUT"   -> "TRANSFER_OUT";
            case "PRODUCTION_IN"  -> "PRODUCTION_IN";
            case "PRODUCTION_OUT" -> "PRODUCTION_OUT";
            case "PRODUCTION_CANCEL" -> "PRODUCTION_CANCEL";
            case "WASTE"          -> "WASTE";
            case "COUNT"          -> "COUNT";
            default               -> movementType;
        };
    }
}
