package com.kaknnea.pos.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import lombok.Data;

public class UnitDtos {
    @Data
    public static class UnitRequest {
        @NotBlank
        private String code;
        private String name;
        @NotBlank
        private String nameEn;
        @NotBlank
        private String nameKm;
        @NotBlank
        private String symbol;
        @NotBlank
        private String baseUnitGroup;
        private Long baseUnitId;
        private boolean baseUnit = true;
        @NotNull
        @DecimalMin(value = "0.000001")
        private BigDecimal conversionFactor = BigDecimal.ONE;
        private boolean active = true;
    }

    @Data
    public static class UnitStatusRequest {
        private boolean active;
    }

    @Data
    public static class UnitResponse {
        private Long id;
        private String code;
        private String name;
        private String nameEn;
        private String nameKm;
        private String symbol;
        private String baseUnitGroup;
        private Long baseUnitId;
        private String baseUnitCode;
        private String baseUnitName;
        private String baseUnitNameEn;
        private String baseUnitNameKm;
        private boolean baseUnit;
        private BigDecimal conversionFactor;
        private boolean active = true;
        private long productUsageCount;
        private long supplierCatalogUsageCount;
        private long usageCount;
        private long derivedUnitCount;
    }
}
