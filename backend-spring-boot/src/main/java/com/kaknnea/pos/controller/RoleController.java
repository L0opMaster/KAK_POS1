package com.kaknnea.pos.controller;

import com.kaknnea.pos.domain.Permission;
import com.kaknnea.pos.domain.Role;
import com.kaknnea.pos.dto.RolePermissionDtos;
import com.kaknnea.pos.repository.PermissionRepository;
import com.kaknnea.pos.repository.RoleRepository;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Set;

@RestController
@RequestMapping("/api/roles")
public class RoleController {
    private final RoleRepository roleRepository;
    private final PermissionRepository permissionRepository;

    public RoleController(RoleRepository roleRepository, PermissionRepository permissionRepository) {
        this.roleRepository = roleRepository;
        this.permissionRepository = permissionRepository;
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('OWNER')")
    public List<Role> list() {
        return roleRepository.findAll();
    }

    @GetMapping("/{id}/permissions")
    @PreAuthorize("hasRole('ADMIN') or hasRole('OWNER')")
    public Set<Permission> rolePermissions(@PathVariable Long id) {
        Role role = roleRepository.findById(id).orElseThrow();
        return role.getPermissions();
    }

    @PutMapping("/{id}/permissions")
    @PreAuthorize("hasRole('ADMIN') or hasRole('OWNER')")
    public Role updatePermissions(@PathVariable Long id, @RequestBody RolePermissionDtos.RolePermissionUpdate request) {
        Role role = roleRepository.findById(id).orElseThrow();
        role.getPermissions().clear();
        if (request.getPermissions() != null) {
            for (String name : request.getPermissions()) {
                Permission p = permissionRepository.findByName(name).orElseThrow();
                role.getPermissions().add(p);
            }
        }
        return roleRepository.save(role);
    }

    @PutMapping("/{id}/permissions/grant-all")
    @PreAuthorize("hasRole('ADMIN') or hasRole('OWNER')")
    public Role grantAllPermissionsToRole(@PathVariable Long id) {
        Role role = roleRepository.findById(id).orElseThrow();
        var allPermissions = permissionRepository.findAll();
        role.getPermissions().clear();
        role.getPermissions().addAll(allPermissions);
        return roleRepository.save(role);
    }

    @PutMapping("/permissions/grant-all")
    @PreAuthorize("hasRole('ADMIN') or hasRole('OWNER')")
    public java.util.List<Role> grantAllPermissionsToAllRoles() {
        var allPermissions = permissionRepository.findAll();
        var roles = roleRepository.findAll();
        for (Role r : roles) {
            r.getPermissions().clear();
            r.getPermissions().addAll(allPermissions);
        }
        return roleRepository.saveAll(roles);
    }
}
