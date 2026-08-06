package com.kaknnea.pos.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

public class ExpenseDtos {

    @Data
    public static class ExpenseCategoryRequest {
        @NotBlank
        private String nameEn;
        @NotBlank
        private String nameKm;
        private String color = "#6366f1";
        private boolean active = true;
    }

    @Data
    public static class ExpenseCategoryResponse {
        private Long id;
        private String nameEn;
        private String nameKm;
        private String color;
        private boolean active;
    }

    @Data
    public static class ExpenseRequest {
        @NotNull
        private String expenseDate;
        @NotNull
        private Long categoryId;
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
    public static class ExpenseResponse {
        private Long id;
        private String expenseNumber;
        private String expenseDate;
        private Long categoryId;
        private String categoryNameEn;
        private String categoryNameKm;
        private String categoryColor;
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
    public static class ExpenseSummary {
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
