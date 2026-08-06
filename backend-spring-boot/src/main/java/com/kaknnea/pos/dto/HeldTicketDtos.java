package com.kaknnea.pos.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;
import lombok.Data;

public class HeldTicketDtos {
    @Data
    public static class UpsertRequest {
        private Long id;
        private String code;
        private String status;
        private String tableName;
        private String storeId;
        private String terminalId;
        private Long shiftId;
        private Long cashierId;
        private Long customerId;
        private String displayName;
        private String comment;
        private Long assignedEmployeeId;
        private Long predefinedTicketId;
        private Integer version;

        @Valid
        private List<LineRequest> items;

        // Backward-compatible alias for older POS clients.
        @Valid
        private List<LineRequest> cart;
    }

    @Data
    public static class LineRequest {
        private Long lineId;
        @NotNull
        private BigDecimal qty;
        private BigDecimal unitPrice;
        private BigDecimal discount;
        private String note;

        @Valid
        @NotNull
        private ProductPayload product;

        // Modifier options chosen for this line (e.g. Sugar Level: 50%) — same
        // shape the POS cart sends at checkout (CartItem.selectedModifiers).
        @Valid
        private List<SelectedModifierPayload> selectedModifiers;
    }

    @Data
    public static class SelectedModifierPayload {
        private Long groupId;
        private String groupName;
        private Long optionId;
        private String optionName;
        private BigDecimal priceDelta;
    }

    @Data
    public static class ProductPayload {
        @NotNull
        private Long id;
        private String sku;
        private String barcode;
        private String nameEn;
        private String nameKm;
        private BigDecimal price;
    }

    @Data
    public static class HeldTicketResponse {
        private Long id;
        private String code;
        private String status;
        private BigDecimal total;
        private String createdAt;
        private String updatedAt;
        private List<LineResponse> items;
        private List<LineResponse> cart;
        private String tableName;
        private String storeId;
        private String terminalId;
        private Long shiftId;
        private Long cashierId;
        private Long customerId;
        private String lockedBy;
        private String lockExpiresAt;
        private Long version;
        private String displayName;
        private String comment;
        private Long assignedEmployeeId;
        private Long predefinedTicketId;
        private String closedReason;
    }

    @Data
    public static class LineResponse {
        private String id;
        private Integer qty;
        private Double discount;
        private Double unitPrice;
        private String note;
        private Long addedAt;
        private ProductResponse product;
        private List<SelectedModifierPayload> selectedModifiers;
    }

    @Data
    public static class ProductResponse {
        private Long id;
        private String sku;
        private String barcode;
        private String nameEn;
        private String nameKm;
        private Double price;
    }

    @Data
    public static class SplitRequest {
        private String idempotencyKey;

        @Valid
        @NotEmpty
        private List<SplitTargetRequest> targets;
    }

    @Data
    public static class SplitTargetRequest {
        private String newTicketName;
        private Long predefinedTicketId;

        @Valid
        @NotEmpty
        private List<SplitLineRequest> items;
    }

    @Data
    public static class SplitLineRequest {
        @NotNull
        private Long lineId;

        @NotNull
        private BigDecimal qty;
    }

    @Data
    public static class SplitResponse {
        private HeldTicketResponse originalTicket;
        private List<HeldTicketResponse> createdTickets;
        private Long operationId;
    }

    @Data
    public static class MergeRequest {
        private String idempotencyKey;

        @NotEmpty
        private List<Long> sourceTicketIds;

        @NotNull
        private Long targetTicketId;
    }

    @Data
    public static class MergeResponse {
        private HeldTicketResponse targetTicket;
        private List<Long> mergedSourceIds;
        private Long operationId;
    }

    @Data
    public static class MoveRequest {
        @NotNull
        private Long targetPredefinedTicketId;
    }

    @Data
    public static class MoveResponse {
        private HeldTicketResponse ticket;
        private Long operationId;
    }

    @Data
    public static class AssignRequest {
        private Long assignedEmployeeId;
    }

    @Data
    public static class AssignResponse {
        private HeldTicketResponse ticket;
        private Long operationId;
    }

    @Data
    public static class PredefinedTicketRequest {
        @NotNull
        private String storeId;

        private String terminalId;

        @NotNull
        private String name;

        @NotNull
        private Integer sortOrder;

        private Boolean active;
    }

    @Data
    public static class PredefinedTicketResponse {
        private Long id;
        private String storeId;
        private String terminalId;
        private String name;
        private Integer sortOrder;
        private Boolean active;
    }

    @Data
    public static class OccupancyResponse {
        private Long predefinedTicketId;
        private String name;
        private boolean occupied;
        private Long ticketId;
        private String ticketCode;
    }
}
