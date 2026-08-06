package com.kaknnea.pos.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.List;

public class AuthDtos {
    @Data
    public static class LoginRequest {
        @Email
        @NotBlank
        private String email;
        @NotBlank
        private String password;

        private String terminalId;
    }



    @Data
    public static class LoginResponse {
        private String token;
        private UserResponse user;
    }

    @Data
    public static class UserResponse {
        private Long id;
        private String email;
        private String fullName;
        private List<String> roles;
        private List<String> permissions;
    }
}
