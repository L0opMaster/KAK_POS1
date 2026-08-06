package com.kaknnea.pos.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

public class PurchaseDtos {
    @Data
    public static class PurchaseLineRequest {
        @NotNull
        private Long productId;
        @NotNull
        private BigDecimal quantity;
        @NotNull
        private BigDecimal unitCost;
    }

    @Data
    public static class PurchaseCreateRequest {
        @NotNull
        private Long supplierId;
        private double taxRate = 0.0;
        /** Which store is receiving this stock. Defaults to store 1 when omitted (single-store setups). */
        private Long storeId;
        @Valid
        @NotNull
        private List<PurchaseLineRequest> lines;
    }

    @Data
    public static class PurchasePayRequest {
        @NotNull
        private BigDecimal amount;
    }

    @Data
    public static class PurchaseResponse {
        private Long id;
        private Long supplierId;
        private String status;
        private BigDecimal subtotal;
        private BigDecimal taxAmount;
        private BigDecimal totalAmount;
        private BigDecimal paidAmount;
        private List<PurchaseLineResponse> lines;
    }

    @Data
    public static class PurchaseLineResponse {
        private Long productId;
        private String productNameEn;
        private String productNameKm;
        private String purchaseUnitCode;
        private BigDecimal quantity;
        private BigDecimal unitCost;
        private BigDecimal lineTotal;
    }
}
