package com.kaknnea.pos.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

public class RecurringInvoiceDtos {

    @Data
    public static class RecurringLineItem {
        private Long productId;
        private BigDecimal quantity;
        private BigDecimal unitPrice;
        private BigDecimal lineDiscount = BigDecimal.ZERO;
        private String note;
    }

    @Data
    public static class CreateRequest {
        private String name;
        private String description;
        private String frequency;          // DAILY, WEEKLY, MONTHLY, YEARLY
        private int intervalCount = 1;
        private Integer dayOfWeek;         // 0=Sun..6=Sat
        private Integer dayOfMonth;        // 1-31
        private Integer monthOfYear;       // 1-12
        private String nextRunDate;        // ISO date string
        private String endDate;
        private Integer maxOccurrences;

        // Invoice defaults
        private Long customerId;
        private String displayName;
        private String paymentTerms = "CASH";
        private BigDecimal deliveryCharge = BigDecimal.ZERO;
        private BigDecimal otherCharge = BigDecimal.ZERO;
        private BigDecimal depositAmount = BigDecimal.ZERO;
        private String note;
        private BigDecimal invoiceDiscount = BigDecimal.ZERO;
        private double taxRate = 0.0;
        private String deliveryRecipientName;
        private String deliveryPhone;
        private String deliveryAddress;

        // Line items
        private List<RecurringLineItem> lines;
    }

    @Data
    public static class UpdateRequest {
        private String name;
        private String description;
        private String frequency;
        private Integer intervalCount;
        private Integer dayOfWeek;
        private Integer dayOfMonth;
        private Integer monthOfYear;
        private String nextRunDate;
        private String endDate;
        private Integer maxOccurrences;
        private Boolean active;
        private Long customerId;
        private String displayName;
        private String paymentTerms;
        private BigDecimal deliveryCharge;
        private BigDecimal otherCharge;
        private BigDecimal depositAmount;
        private String note;
        private BigDecimal invoiceDiscount;
        private Double taxRate;
        private String deliveryRecipientName;
        private String deliveryPhone;
        private String deliveryAddress;
        private List<RecurringLineItem> lines;
    }

    @Data
    public static class TemplateResponse {
        private Long id;
        private String name;
        private String description;
        private String frequency;
        private int intervalCount;
        private Integer dayOfWeek;
        private Integer dayOfMonth;
        private Integer monthOfYear;
        private String nextRunDate;
        private String endDate;
        private Integer maxOccurrences;
        private int occurrencesCount;
        private Long customerId;
        private String customerName;
        private String displayName;
        private String paymentTerms;
        private BigDecimal deliveryCharge;
        private BigDecimal otherCharge;
        private BigDecimal depositAmount;
        private String note;
        private BigDecimal invoiceDiscount;
        private double taxRate;
        private String deliveryRecipientName;
        private String deliveryPhone;
        private String deliveryAddress;
        private List<RecurringLineItem> lines;
        private boolean active;
        private String lastGeneratedAt;
        private Long lastInvoiceId;
        private String lastInvoiceNumber;
        private String createdAt;
    }
}
