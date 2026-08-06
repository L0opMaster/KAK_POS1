package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

public class TableDtos {
    @Data
    public static class TableCreateRequest {
        @NotBlank
        private String tableNumber;
        private String displayName;
        @NotNull
        private Integer capacity = 4;
        private String section;
        private String notes;
    }

    @Data
    public static class TableUpdateRequest {
        private String displayName;
        @NotNull
        private Integer capacity = 4;
        private String section;
        private String notes;
        private String status;
        private Boolean isActive;
    }

    @Data
    public static class TableResponse {
        private Long id;
        private String tableNumber;
        private String displayName;
        private String status;
        private Integer capacity;
        private String section;
        private String notes;
        private Boolean isActive;
        private String createdAt;
        private String updatedAt;
    }

    @Data
    public static class TableSearchRequest {
        private String search;
        private String status;
        private String section;
        private Boolean isActive;
        private Integer page = 0;
        private Integer size = 20;
    }

    @Data
    public static class TablePageResponse {
        private List<TableResponse> content;
        private Integer page;
        private Integer size;
        private Long totalElements;
        private Integer totalPages;
    }

    @Data
    public static class TableStatsResponse {
        private Long totalTables;
        private Long activeTables;
        private Long availableTables;
        private Long occupiedTables;
        private Long reservedTables;
    }
}