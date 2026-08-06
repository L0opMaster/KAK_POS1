package com.kaknnea.pos.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

public class OtherIncomeDtos {
    @Data
    public static class CategoryRequest {
        @NotBlank
        private String nameEn;
        @NotBlank
        private String nameKm;
        private String color = "#16a34a";
        private boolean active = true;
    }

    @Data
    public static class CategoryResponse {
        private Long id;
        private String nameEn;
        private String nameKm;
        private String color;
        private boolean active;
    }

    @Data
    public static class IncomeRequest {
        @NotNull
        private String incomeDate;
        @NotNull
        private Long categoryId;
        private String payerName;
        @NotBlank
        private String description;
        @NotNull
        @DecimalMin("0.00")
        private BigDecimal amount;
        @Size(max = 30)
        private String paymentMethod = "CASH";
        private String reference;
        private String note;
    }

    @Data
    public static class IncomeResponse {
        private Long id;
        private String incomeNumber;
        private String incomeDate;
        private Long categoryId;
        private String categoryNameEn;
        private String categoryNameKm;
        private String categoryColor;
        private String payerName;
        private String description;
        private BigDecimal amount;
        private String paymentMethod;
        private String reference;
        private String note;
        private String status;
        private String createdByName;
        private String approvedByName;
        private String approvedAt;
        private String createdAt;
    }

    @Data
    public static class Summary {
        private BigDecimal totalThisMonth;
        private BigDecimal totalLastMonth;
        private long countDraft;
        private long countApproved;
        private List<CategoryBreakdown> byCategory;
    }

    @Data
    public static class CategoryBreakdown {
        private Long categoryId;
        private String categoryNameEn;
        private String categoryNameKm;
        private String categoryColor;
        private BigDecimal total;
    }
}
