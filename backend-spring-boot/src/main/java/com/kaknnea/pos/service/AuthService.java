package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.LoginAudit;
import com.kaknnea.pos.domain.Permission;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.domain.Device;
import com.kaknnea.pos.dto.AuthDtos;
import com.kaknnea.pos.dto.SecurityDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.DeviceRepository;
import com.kaknnea.pos.repository.LoginAuditRepository;
import com.kaknnea.pos.repository.PermissionRepository;
import com.kaknnea.pos.repository.PasswordResetTokenRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.security.JwtUtil;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class AuthService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final LoginAuditRepository loginAuditRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final DeviceRepository deviceRepository;
    private final PermissionRepository permissionRepository;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtUtil jwtUtil,
                       LoginAuditRepository loginAuditRepository, PasswordResetTokenRepository passwordResetTokenRepository,
                       DeviceRepository deviceRepository, PermissionRepository permissionRepository) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.loginAuditRepository = loginAuditRepository;
        this.passwordResetTokenRepository = passwordResetTokenRepository;
        this.deviceRepository = deviceRepository;
        this.permissionRepository = permissionRepository;
    }

    public AuthDtos.LoginResponse login(AuthDtos.LoginRequest request, String ip, String userAgent) {
        User user = userRepository.findByEmail(request.getEmail()).orElse(null);
        if (user == null) {
            logLogin(null, request.getEmail(), false, ip, userAgent);
            throw new ApiException("Invalid credentials");
        }
        if (user.getLockoutUntil() != null && user.getLockoutUntil().isAfter(Instant.now())) {
            logLogin(user, user.getEmail(), false, ip, userAgent);
            throw new ApiException("Account locked. Try again later.");
        }
        if (!user.isActive()) {
            logLogin(user, user.getEmail(), false, ip, userAgent);
            throw new ApiException("User inactive");
        }
        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            user.setFailedLoginAttempts(user.getFailedLoginAttempts() + 1);
            if (user.getFailedLoginAttempts() >= 5) {
                user.setLockoutUntil(Instant.now().plusSeconds(15 * 60));
                user.setFailedLoginAttempts(0);
            }
            userRepository.save(user);
            logLogin(user, user.getEmail(), false, ip, userAgent);
            throw new ApiException("Invalid credentials");
        }
        user.setFailedLoginAttempts(0);
        user.setLockoutUntil(null);
        user.setLastLoginAt(Instant.now());
        if (request.getTerminalId() != null && !request.getTerminalId().isBlank()) {
            user.setLastLoginTerminal(request.getTerminalId());
            upsertDevice(user, request.getTerminalId());
        }
        userRepository.save(user);
        var roles = user.getRoles().stream().map(r -> r.getName()).collect(Collectors.toList());
        var permissions = new LinkedHashSet<>(user.getRoles().stream()
                .flatMap(r -> r.getPermissions().stream())
                .map(Permission::getName)
                .collect(Collectors.toSet()));
        if (roles.stream().anyMatch(role -> "OWNER".equals(role) || "ADMIN".equals(role) || "SYSTEM_ADMIN".equals(role))) {
            permissions.addAll(permissionRepository.findAll().stream().map(Permission::getName).toList());
        }
        List<String> permissionList = List.copyOf(permissions);
        String token = jwtUtil.generateToken(user.getEmail(), roles, permissionList);
        AuthDtos.LoginResponse response = new AuthDtos.LoginResponse();
        response.setToken(token);
        AuthDtos.UserResponse userResponse = new AuthDtos.UserResponse();
        userResponse.setId(user.getId());
        userResponse.setEmail(user.getEmail());
        userResponse.setFullName(user.getFullName());
        userResponse.setRoles(roles);
        userResponse.setPermissions(permissionList);
        response.setUser(userResponse);
        logLogin(user, user.getEmail(), true, ip, userAgent);
        return response;
    }

    private void upsertDevice(User user, String terminalId) {
        Device device = deviceRepository.findByTerminalId(terminalId).orElseGet(Device::new);
        device.setTerminalId(terminalId);
        device.setUser(user);
        device.setLastSeenAt(Instant.now());
        device.setActive(true);
        if (device.getName() == null) {
            device.setName("Terminal " + terminalId);
        }
        deviceRepository.save(device);
    }

    private void logLogin(User user, String email, boolean success, String ip, String userAgent) {
        LoginAudit audit = new LoginAudit();
        audit.setUser(user);
        audit.setEmail(email);
        audit.setSuccess(success);
        audit.setIpAddress(ip);
        audit.setUserAgent(userAgent);
        loginAuditRepository.save(audit);
    }

    public SecurityDtos.PasswordResetResponse requestPasswordReset(SecurityDtos.PasswordResetRequest request) {
        User user = userRepository.findByEmail(request.getEmail()).orElseThrow(() -> new ApiException("User not found"));
        var token = new com.kaknnea.pos.domain.PasswordResetToken();
        token.setUser(user);
        token.setToken(UUID.randomUUID().toString().replace("-", ""));
        token.setExpiresAt(Instant.now().plusSeconds(30 * 60));
        passwordResetTokenRepository.save(token);
        SecurityDtos.PasswordResetResponse resp = new SecurityDtos.PasswordResetResponse();
        resp.setToken(token.getToken());
        resp.setMessage("Reset token generated. Deliver via email/SMS in production.");
        return resp;
    }

    public SecurityDtos.PasswordResetResponse resetPassword(SecurityDtos.PasswordResetConfirm request) {
        var token = passwordResetTokenRepository.findByToken(request.getToken())
                .orElseThrow(() -> new ApiException("Invalid token"));
        if (token.isUsed() || token.getExpiresAt().isBefore(Instant.now())) {
            throw new ApiException("Token expired or used");
        }
        User user = token.getUser();
        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
        token.setUsed(true);
        passwordResetTokenRepository.save(token);
        SecurityDtos.PasswordResetResponse resp = new SecurityDtos.PasswordResetResponse();
        resp.setMessage("Password reset successful");
        return resp;
    }

    public SecurityDtos.PasswordResetResponse changePassword(String email, SecurityDtos.PasswordChangeRequest request) {
        User user = userRepository.findByEmail(email).orElseThrow(() -> new ApiException("User not found"));
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPasswordHash())) {
            throw new ApiException("Current password is incorrect");
        }
        if (passwordEncoder.matches(request.getNewPassword(), user.getPasswordHash())) {
            throw new ApiException("New password must be different from the current password");
        }

        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        user.setFailedLoginAttempts(0);
        user.setLockoutUntil(null);
        userRepository.save(user);

        SecurityDtos.PasswordResetResponse resp = new SecurityDtos.PasswordResetResponse();
        resp.setMessage("Password changed successfully");
        return resp;
    }
}
