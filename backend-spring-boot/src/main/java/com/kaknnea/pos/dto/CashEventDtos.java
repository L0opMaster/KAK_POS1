package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;

public class CashEventDtos {
    @Data
    public static class CashEventRequest {
        @NotBlank
        private String type;

        @NotNull
        private BigDecimal amount;

        private String reason;

        private Long saleId;
    }

    @Data
    public static class CashEventResponse {
        private Long id;
        private Long shiftId;
        private String type;
        private BigDecimal amount;
        private String reason;
        private Long saleId;
        private Instant createdAt;
        private Long userId;
    }
}

