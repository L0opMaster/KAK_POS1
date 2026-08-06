package com.kaknnea.pos.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

public class SecurityDtos {
    @Data
    public static class PasswordResetRequest {
        @Email
        @NotBlank
        private String email;
    }

    @Data
    public static class PasswordResetConfirm {
        @NotBlank
        private String token;
        @NotBlank
        private String newPassword;
    }

    @Data
    public static class PasswordChangeRequest {
        @NotBlank
        private String currentPassword;
        @NotBlank
        private String newPassword;
    }

    @Data
    public static class PasswordResetResponse {
        private String token;
        private String message;
    }
}
