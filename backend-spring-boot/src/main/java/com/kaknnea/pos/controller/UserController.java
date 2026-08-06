package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.UserDtos;
import com.kaknnea.pos.service.UserService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/users")
public class UserController {
    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('ADMIN', 'OWNER', 'MANAGER')")
    public List<UserDtos.UserResponse> list() {
        return userService.list();
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('OWNER')")
    public UserDtos.UserResponse create(@Valid @RequestBody UserDtos.UserCreateRequest request) {
        return userService.create(request);
    }

    @PutMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN') or hasRole('OWNER')")
    public UserDtos.UserResponse setStatus(@PathVariable Long id, @RequestBody UserDtos.UserStatusRequest request) {
        return userService.setStatus(id, request.isActive());
    }
}
