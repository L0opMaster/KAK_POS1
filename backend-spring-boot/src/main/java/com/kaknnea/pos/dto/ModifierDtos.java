package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;
import lombok.Data;

public class ModifierDtos {
    @Data
    public static class ModifierGroupRequest {
        @NotBlank
        private String nameEn;
        @NotBlank
        private String nameKm;
        private boolean required = false;
        private boolean multiSelect = false;
        private boolean active = true;
        private int displayOrder = 0;
    }

    @Data
    public static class ModifierOptionRequest {
        @NotBlank
        private String nameEn;
        @NotBlank
        private String nameKm;
        @NotNull
        private BigDecimal priceDelta;
        private boolean active = true;
        private int displayOrder = 0;
    }

    @Data
    public static class ModifierOptionResponse {
        private Long id;
        private String nameEn;
        private String nameKm;
        private BigDecimal priceDelta;
        private boolean active;
        private int displayOrder;
    }

    @Data
    public static class ModifierGroupResponse {
        private Long id;
        private String nameEn;
        private String nameKm;
        private boolean required;
        private boolean multiSelect;
        private boolean active;
        private int displayOrder;
        private List<ModifierOptionResponse> options;
    }

    @Data
    public static class ProductModifiersResponse {
        private Long groupId;
        private String groupNameEn;
        private String groupNameKm;
        private boolean required;
        private boolean multiSelect;
        private List<ModifierOptionResponse> options;
    }
}
