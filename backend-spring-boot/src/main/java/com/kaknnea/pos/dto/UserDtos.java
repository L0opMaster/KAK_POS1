package com.kaknnea.pos.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.List;

public class UserDtos {
    @Data
    public static class UserCreateRequest {
        @Email
        @NotBlank
        private String email;
        @NotBlank
        private String fullName;
        @NotBlank
        private String password;
        private List<String> roles;
    }

    @Data
    public static class UserResponse {
        private Long id;
        private String email;
        private String fullName;
        private boolean active;
        private List<String> roles;
    }

    @Data
    public static class UserStatusRequest {
        private boolean active;
    }
}
