package com.kaknnea.pos.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public class TransferDtos {
    @Data
    public static class TransferLineRequest {
        @NotNull
        private Long productId;
        @NotNull
        @DecimalMin(value = "0.01", message = "Transfer quantity must be greater than zero")
        private BigDecimal quantity;
    }

    @Data
    public static class TransferCreateRequest {
        @NotNull
        private Long fromStoreId;
        @NotNull
        private Long toStoreId;
        private String notes;
        @Valid
        @NotEmpty(message = "Add at least one transfer line")
        private List<TransferLineRequest> lines;
    }

    @Data
    public static class TransferResponse {
        private Long id;
        private String transferNumber;
        private Long fromStoreId;
        private String fromStoreName;
        private Long toStoreId;
        private String toStoreName;
        private String status;
        private String notes;
        private Instant createdAt;
        private Instant completedAt;
        private List<TransferLineResponse> lines;
    }

    @Data
    public static class TransferLineResponse {
        private Long productId;
        private String productNameEn;
        private String stockUnitCode;
        private BigDecimal quantity;
    }
}
