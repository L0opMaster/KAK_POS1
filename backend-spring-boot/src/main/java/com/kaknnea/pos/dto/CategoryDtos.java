package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

public class CategoryDtos {
    @Data
    public static class CategoryRequest {
        @NotBlank
        private String nameEn;
        @NotBlank
        private String nameKm;
        private Long parentId;
        private boolean active = true;
    }

    @Data
    public static class CategoryResponse {
        private Long id;
        private String nameEn;
        private String nameKm;
        private Long parentId;
        private boolean active;
    }
}
