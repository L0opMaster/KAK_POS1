package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.AuthDtos;
import com.kaknnea.pos.dto.SecurityDtos;
import com.kaknnea.pos.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
public class AuthAliasController {
    private final AuthService authService;

    public AuthAliasController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    public AuthDtos.LoginResponse login(@Valid @RequestBody AuthDtos.LoginRequest request, HttpServletRequest http) {
        return authService.login(request, http.getRemoteAddr(), http.getHeader("User-Agent"));
    }

    @PostMapping("/request-reset")
    public SecurityDtos.PasswordResetResponse requestReset(
            @Valid @RequestBody SecurityDtos.PasswordResetRequest request) {
        return authService.requestPasswordReset(request);
    }

    @PostMapping("/reset")
    public SecurityDtos.PasswordResetResponse reset(@Valid @RequestBody SecurityDtos.PasswordResetConfirm request) {
        return authService.resetPassword(request);
    }

    @PostMapping("/change-password")
    public SecurityDtos.PasswordResetResponse changePassword(
            @Valid @RequestBody SecurityDtos.PasswordChangeRequest request,
            Authentication authentication) {
        return authService.changePassword(authentication.getName(), request);
    }
}
