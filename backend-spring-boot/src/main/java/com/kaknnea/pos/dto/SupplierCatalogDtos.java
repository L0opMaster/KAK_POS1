package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

public class SupplierCatalogDtos {
    @Data
    public static class SupplierCatalogItemRequest {
        @NotNull
        private Long supplierId;
        @NotNull
        private Long productId;
        private String supplierSku;
        private Long purchaseUnitId;
        private BigDecimal lastCost;
        private Integer leadTimeDays;
        private BigDecimal minimumOrderQuantity;
        private BigDecimal packSize;
        private boolean active = true;
    }

    @Data
    public static class SupplierCatalogItemResponse {
        private Long id;
        private Long supplierId;
        private String supplierName;
        private Long productId;
        private String productNameEn;
        private String productNameKm;
        private String supplierSku;
        private Long purchaseUnitId;
        private String purchaseUnitCode;
        private BigDecimal lastCost;
        private Integer leadTimeDays;
        private BigDecimal minimumOrderQuantity;
        private BigDecimal packSize;
        private boolean active;
    }
}
