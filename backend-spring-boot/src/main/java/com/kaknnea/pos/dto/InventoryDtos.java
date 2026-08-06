package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public class InventoryDtos {
    @Data
    public static class StockResponse {
        private Long id;
        private Long productId;
        private String productNameEn;
        private String productNameKm;
        private String productCode;
        private BigDecimal quantity;
        private BigDecimal lowStockThreshold;
        private BigDecimal unitCost;
        private BigDecimal totalValue;
        private Long storeId;
        private String storeName;
        private String stockUnitCode;
        private Instant updatedAt;
    }

    @Data
    public static class StockAdjustRequest {
        @NotNull
        private Long productId;
        @NotNull
        private BigDecimal quantity;
        private Long storeId;
        private String reason;
    }

    @Data
    public static class StockInRequest {
        @NotNull
        private Long productId;
        @NotNull
        private BigDecimal quantity;
        private Long storeId;
        private String reason;
    }

    @Data
    public static class StockMovementResponse {
        private Long id;
        private Long productId;
        private String productNameEn;
        private String storeName;
        private Long storeId;
        private String movementType;
        private BigDecimal quantity;
        private String reason;
        private String createdBy;
        private java.time.Instant createdAt;
    }

    @Data
    public static class StockValuationResponse {
        private BigDecimal totalValue;
        private String valuedAt;
        private List<StockResponse> items;
    }

    @Data
    public static class InventoryCountPostResponse {
        private int itemsPosted;
        private int variancesApplied;
        private String snapshotDate;
        private Long storeId;
    }

    @Data
    public static class InventoryCountEntryRequest {
        @NotNull
        private LocalDate snapshotDate;
        @NotNull
        private Long storeId;
        @NotNull
        private Long snapshotId;
        @NotNull
        private BigDecimal countedQuantity;
        private String notes;
    }

    @Data
    public static class InventoryCountPostRequest {
        @NotNull
        private LocalDate snapshotDate;
        @NotNull
        private Long storeId;
    }

    @Data
    public static class InventoryCountEntryResponse {
        private Long snapshotId;
        private Long productId;
        private String productNameEn;
        private String productNameKm;
        private BigDecimal expectedQuantity;
        private BigDecimal countedQuantity;
        private BigDecimal varianceQuantity;
        private String countStatus;
        private String notes;
    }
}
