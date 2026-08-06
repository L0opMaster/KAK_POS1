package com.kaknnea.pos.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;
import lombok.Data;

public class ProductionDtos {

    @Data
    public static class RecipeLineRequest {
        @NotNull
        private Long componentProductId;
        @NotNull
        private BigDecimal componentQuantity;
    }

    @Data
    public static class RecipeRequest {
        @NotBlank
        private String name;
        @NotNull
        private Long outputProductId;
        @NotNull
        private BigDecimal outputQuantity;
        private boolean active = true;
        private String notes;
        @Valid
        @NotNull
        private List<RecipeLineRequest> lines;
    }

    /** PUT /recipes/{id} — output product cannot change */
    @Data
    public static class RecipeUpdateRequest {
        @NotBlank
        private String name;
        @NotNull
        private BigDecimal outputQuantity;
        private boolean active = true;
        private String notes;
        @Valid
        @NotNull
        private List<RecipeLineRequest> lines;
    }

    @Data
    public static class RecipeLineResponse {
        private Long id;
        private Long componentProductId;
        private String componentProductNameEn;
        private BigDecimal componentQuantity;
        private String componentStockUnitCode;
    }

    @Data
    public static class RecipeResponse {
        private Long id;
        private String name;
        private Long outputProductId;
        private String outputProductNameEn;
        private BigDecimal outputQuantity;
        private boolean active;
        private String notes;
        private List<RecipeLineResponse> lines;
    }

    @Data
    public static class ProductionOrderRequest {
        @NotNull
        private Long recipeId;
        private Long storeId;
        @NotNull
        private BigDecimal plannedQuantity;
        private String notes;
    }

    @Data
    public static class CompleteOrderRequest {
        @NotNull
        private BigDecimal producedQuantity;
        private BigDecimal wasteQuantity = BigDecimal.ZERO;
        private String notes;
    }

    @Data
    public static class CancelOrderRequest {
        private String reason;
    }

    @Data
    public static class ProductionOrderLineResponse {
        private Long id;
        private Long componentProductId;
        private String componentProductNameEn;
        private BigDecimal plannedQuantity;
        private BigDecimal consumedQuantity;
    }

    @Data
    public static class ProductionOrderResponse {
        private Long id;
        private String orderNumber;
        private Long recipeId;
        private String recipeName;
        private Long storeId;
        private String storeName;
        private String status;
        private BigDecimal plannedQuantity;
        private BigDecimal producedQuantity;
        private BigDecimal wasteQuantity;
        private Double yieldPercent;
        private String postedAt;
        private String startedAt;
        private String completedAt;
        private String cancelledAt;
        private String cancelReason;
        private String notes;
        private String createdBy;
        private List<ProductionOrderLineResponse> lines;
    }

    /** POST /orders/check-availability */
    @Data
    public static class AvailabilityCheckRequest {
        @NotNull
        private Long recipeId;
        @NotNull
        private Long storeId;
        @NotNull
        private BigDecimal producedQuantity;
    }

    @Data
    public static class AvailabilityCheckResponse {
        private boolean available;
        private List<ComponentAvailability> components;

        @Data
        public static class ComponentAvailability {
            private Long productId;
            private String productNameEn;
            private String stockUnitCode;
            private BigDecimal required;
            private BigDecimal onHand;
            private boolean sufficient;
        }
    }
}
