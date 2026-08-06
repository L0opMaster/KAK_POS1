package com.kaknnea.pos.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public class PriceListDtos {
    @Data
    public static class PriceListItemRequest {
        @NotNull
        private Long productId;
        @NotNull
        private BigDecimal price;
        private BigDecimal minimumOrderQty;
    }

    @Data
    public static class PriceListRequest {
        @NotBlank
        private String name;
        @NotBlank
        private String currencyCode;
        private String customerGroup;
        private Long storeId;
        private Instant startsAt;
        private Instant endsAt;
        private int priority;
        private boolean active = true;
        @Valid
        private List<PriceListItemRequest> items;
    }

    @Data
    public static class PriceListItemResponse {
        private Long id;
        private Long productId;
        private String productNameEn;
        private String productNameKm;
        private BigDecimal price;
        private BigDecimal minimumOrderQty;
    }

    @Data
    public static class PriceListResponse {
        private Long id;
        private String name;
        private String currencyCode;
        private String customerGroup;
        private Long storeId;
        private String storeName;
        private Instant startsAt;
        private Instant endsAt;
        private int priority;
        private boolean active;
        private List<PriceListItemResponse> items;
    }
}
