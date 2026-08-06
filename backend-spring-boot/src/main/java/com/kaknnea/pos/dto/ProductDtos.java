package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

public class ProductDtos {
    @Data
    public static class ProductImageRequest {
        private String url;
        private boolean primary;
    }

    @Data
    public static class ProductImageResponse {
        private Long id;
        private String url;
        private boolean primary;
    }

    @Data
    public static class ProductBundleComponentRequest {
        @NotNull
        private Long componentProductId;
        @NotNull
        private BigDecimal componentQuantity;
    }

    @Data
    public static class ProductBundleComponentResponse {
        private Long id;
        private Long componentProductId;
        private String componentProductNameEn;
        private String componentProductNameKm;
        private BigDecimal componentQuantity;
    }

    @Data
    public static class ProductRequest {
        @NotBlank
        private String sku;
        @NotBlank
        private String barcode;
        @NotBlank
        private String nameEn;
        @NotBlank
        private String nameKm;
        private String imageUrl;
        @NotNull
        private BigDecimal cost;
        @NotNull
        private BigDecimal price;
        private boolean active = true;
        private boolean sellable = true;
        private boolean purchasable = false;
        private boolean trackInventory = false;
        @NotBlank
        private String productType = "SALE_ITEM";
        @NotNull
        private BigDecimal lowStockThreshold = new BigDecimal("5.00");
        @NotNull
        private Long categoryId;
        private Long parentProductId;
        private String variantLabel;
        private String bundleMode;
        private Long saleUnitId;
        private Long purchaseUnitId;
        private Long stockUnitId;
        private BigDecimal initialStock = BigDecimal.ZERO;
        private List<ProductImageRequest> images;
        private List<ProductBundleComponentRequest> bundleComponents;
    }

    @Data
    public static class SampleSeedRequest {
        private String businessType;
        private Boolean resetAll;
    }

    @Data
    public static class SampleSeedResponse {
        private String businessType;
        private int categoriesCreated;
        private int productsCreated;
    }

    @Data
    public static class ModifierOptionSummary {
        private Long id;
        private String nameEn;
        private String nameKm;
        private BigDecimal priceDelta;
    }

    @Data
    public static class ModifierGroupSummary {
        private Long id;
        private String nameEn;
        private String nameKm;
        private boolean required;
        private boolean multiSelect;
        private List<ModifierOptionSummary> options;
    }

    @Data
    public static class ProductResponse {
        private Long id;
        private String sku;
        private String barcode;
        private String nameEn;
        private String nameKm;
        private String imageUrl;
        private BigDecimal cost;
        private BigDecimal price;
        private BigDecimal resolvedPrice;
        private boolean active;
        private boolean sellable;
        private boolean purchasable;
        private boolean trackInventory;
        private String productType;
        private BigDecimal lowStockThreshold;
        private Long categoryId;
        private String categoryNameEn;
        private String categoryNameKm;
        private Long parentProductId;
        private String parentProductNameEn;
        private String variantLabel;
        private String bundleMode;
        private Long saleUnitId;
        private String saleUnitCode;
        private String saleUnitBaseGroup;
        private BigDecimal saleUnitConversionFactor;
        private Long purchaseUnitId;
        private String purchaseUnitCode;
        private Long stockUnitId;
        private String stockUnitCode;
        private String stockUnitBaseGroup;
        private BigDecimal stockUnitConversionFactor;
        private BigDecimal stock;
        private BigDecimal availableSaleQty;
        private boolean outOfStock;
        private boolean lowStock;
        private List<ProductImageResponse> images;
        private List<ProductBundleComponentResponse> bundleComponents;
        private List<ModifierGroupSummary> modifierGroups;
    }
}
