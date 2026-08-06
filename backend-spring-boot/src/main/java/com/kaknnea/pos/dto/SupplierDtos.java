package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

public class SupplierDtos {
    @Data
    public static class SupplierRequest {
        @NotBlank
        private String name;
        private String contactPerson;
        private String phone;
        private String email;
        private String address;
        private String paymentTerms;
        private Integer leadTimeDays;
        private String taxId;
        private String defaultCurrency = "KHR";
        private boolean active = true;
        private String notes;
    }

    @Data
    public static class SupplierResponse {
        private Long id;
        private String name;
        private String contactPerson;
        private String phone;
        private String email;
        private String address;
        private String paymentTerms;
        private Integer leadTimeDays;
        private String taxId;
        private String defaultCurrency;
        private boolean active;
        private String notes;
        private Long catalogItemCount;
        private java.math.BigDecimal openPayable;
        private String lastPurchaseDate;
    }
}
