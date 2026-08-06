package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;
import lombok.Data;

public class DeliveryNoteDtos {
    @Data
    public static class DeliveryNoteLineRequest {
        @NotNull
        private Long saleLineId;
        @NotNull
        private BigDecimal quantity;
    }

    @Data
    public static class DeliveryNoteRequest {
        @NotNull
        private Long saleId;
        @NotBlank
        private String deliveryDate;
        private String contactName;
        private String contactPhone;
        private String deliveryAddress;
        private String notes;
        private List<DeliveryNoteLineRequest> lines;
    }

    @Data
    public static class DeliveryNoteStatusRequest {
        @NotBlank
        private String status;
    }

    @Data
    public static class DeliveryNoteLineResponse {
        private Long id;
        private Long saleLineId;
        private Long productId;
        private String productNameEn;
        private BigDecimal quantity;
    }

    @Data
    public static class DeliveryNoteResponse {
        private Long id;
        private String noteNumber;
        private Long saleId;
        private String saleNumber;
        private Long customerId;
        private String customerName;
        private String status;
        private String deliveryDate;
        private String contactName;
        private String contactPhone;
        private String deliveryAddress;
        private String notes;
        private List<DeliveryNoteLineResponse> lines;
    }
}
