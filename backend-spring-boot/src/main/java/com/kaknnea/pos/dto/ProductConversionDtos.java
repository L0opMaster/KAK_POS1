package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

public class ProductConversionDtos {
    @Data
    public static class ConversionRequest {
        @NotNull
        private Long sourceProductId;
        @NotNull
        private Long targetProductId;
        @NotNull
        private Long sourceUnitId;
        @NotNull
        private Long targetUnitId;
        @NotNull
        private BigDecimal ratio;
        @NotNull
        private String conversionType;
        private boolean active = true;
    }

    @Data
    public static class ConversionExecuteRequest {
        @NotNull
        private Long conversionId;
        @NotNull
        private BigDecimal sourceQuantity;
        private Long storeId;
        private String reason;
    }

    @Data
    public static class ConversionResponse {
        private Long id;
        private Long sourceProductId;
        private String sourceProductNameEn;
        private Long targetProductId;
        private String targetProductNameEn;
        private Long sourceUnitId;
        private String sourceUnitCode;
        private Long targetUnitId;
        private String targetUnitCode;
        private BigDecimal ratio;
        private String conversionType;
        private boolean active;
    }

    @Data
    public static class ProductHistoryResponse {
        private List<HistoryEntry> entries;
    }

    @Data
    public static class HistoryEntry {
        private String source;
        private String eventType;
        private BigDecimal quantity;
        private String notes;
        private String createdAt;
    }
}
