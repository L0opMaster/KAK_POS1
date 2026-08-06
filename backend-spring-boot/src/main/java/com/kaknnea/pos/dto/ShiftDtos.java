package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public class ShiftDtos {
    @Data
    public static class OpenShiftRequest {
        @NotNull
        private BigDecimal openingCash;
        private Long storeId;
    }

    @Data
    public static class CloseShiftRequest {
        @NotNull
        private BigDecimal closingCash;
        private Boolean forceClose = false;
        private String managerEmail;
        private String managerPassword;
        private String overrideReason;
    }

    @Data
    public static class ApproveVarianceRequest {
        @NotNull
        private String managerEmail;
        @NotNull
        private String password;
        private String note;
    }

    @Data
    public static class ShiftResponse {
        private Long id;
        private String status;
        private Instant openedAt;
        private Instant closedAt;
        private BigDecimal openingCash;
        private BigDecimal closingCash;
        private BigDecimal expectedCash;
        private BigDecimal variance;
        private Long storeId;
        private String storeName;
        private Long openedBy;
        private Long closedBy;
        private Long approvedBy;
        private String approvalNote;
        private BigDecimal salesTotal;
        private long salesCount;
        private BigDecimal cashSales = BigDecimal.ZERO;
        private BigDecimal cashRefunds = BigDecimal.ZERO;
        private BigDecimal manualCashEvents = BigDecimal.ZERO;
    }

    @Data
    public static class ShiftClosePrecheckResponse {
        private Long shiftId;
        private long openHeldCount;
        private long inProgressCount;
        private BigDecimal outstandingCreditAmount = BigDecimal.ZERO;
        private List<String> blockers;
        private List<TicketBlocker> inProgressTickets = List.of();
        private List<TicketBlocker> heldTickets = List.of();
    }

    @Data
    public static class TicketBlocker {
        private Long saleId;
        private String saleNumber;
        private String status;
        private String customerName;
        private BigDecimal total;
        private BigDecimal paidAmount;
        private BigDecimal balanceDue;
        private Instant createdAt;
    }
}
