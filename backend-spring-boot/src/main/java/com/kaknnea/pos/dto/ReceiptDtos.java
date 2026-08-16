package com.kaknnea.pos.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

public class ReceiptDtos {
    @Data
    public static class ReceiptLine {
        private Long saleLineId;
        private String nameEn;
        private String nameKm;
        private BigDecimal qty;
        private String unitSymbol;
        private BigDecimal unitPrice;
        private BigDecimal modifierAmount;
        private BigDecimal lineTotal;
        private BigDecimal refundedQty;
        private String modifierSummary;
    }

    @Data
    public static class ReceiptPayment {
        private String method;
        private BigDecimal amount;
    }

    @Data
    public static class ReceiptResponse {
        private String businessName;
        private String address;
        private String phone;
        private String website;
        private String currency;
        private String footer;
        private Long saleId;
        private String saleNumber;
        private Long shiftId;
        private Long storeId;
        private String createdAt;
        private String cashierName;
        private String storeName;
        private String customerName;
        private String customerPhone;
        private Long tableId;
        private String tableNumber;
        private String orderMode;
        private String deliveryRecipientName;
        private String deliveryPhone;
        private String deliveryAddress;
        private String deliveryLandmark;
        private String deliveryNote;
        private List<ReceiptLine> lines;
        private List<ReceiptPayment> payments;
        private BigDecimal subtotal;
        private BigDecimal taxAmount;
        private BigDecimal discountAmount;
        private BigDecimal deliveryCharge;
        private BigDecimal otherCharge;
        private BigDecimal total;
        private BigDecimal paidAmount;
        private BigDecimal changeAmount;
        private BigDecimal refundedAmount;
        private BigDecimal oldBalance;
        private BigDecimal totalBalance;
        private String status;
        /** ISO-8601 instant this credit sale is due — null for a non-credit sale. */
        private String creditDueAt;
        /** ISO-8601 instant the credit agreement expires — null if unset/non-credit. */
        private String creditExpiresAt;
        /** OPEN|PARTIALLY_PAID|PAID|OVERDUE|EXPIRED|CANCELLED — null for a non-credit sale. */
        private String creditStatus;
        /** total - paidAmount for THIS sale (not the customer's whole account balance). */
        private BigDecimal remainingBalance;
        private String qrImageData;
        private String logoUrl;

        /** KHR-per-USD rate that was in effect when this sale was created. */
        private BigDecimal exchangeRateKhr;
    }
}
