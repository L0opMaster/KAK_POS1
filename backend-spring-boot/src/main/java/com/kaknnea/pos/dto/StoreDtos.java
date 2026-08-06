package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

public class StoreDtos {
    @Data
    public static class StoreRequest {
        @NotBlank
        private String name;
        private String address;
        private String phone;
    }

    @Data
    public static class StoreResponse {
        private Long id;
        private String name;
        private String address;
        private String phone;
    }
}
