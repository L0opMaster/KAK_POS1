package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Role;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.dto.UserDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.RoleRepository;
import com.kaknnea.pos.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class UserService {
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, RoleRepository roleRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public List<UserDtos.UserResponse> list() {
        return userRepository.findAll().stream().map(this::toResponse).collect(Collectors.toList());
    }

    public UserDtos.UserResponse create(UserDtos.UserCreateRequest request) {
        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new ApiException("Email already exists");
        }
        User user = new User();
        user.setEmail(request.getEmail());
        user.setFullName(request.getFullName());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        if (request.getRoles() != null) {
            for (String r : request.getRoles()) {
                Role role = roleRepository.findByName(r).orElseThrow(() -> new ApiException("Role not found: " + r));
                user.getRoles().add(role);
            }
        }
        return toResponse(userRepository.save(user));
    }

    public UserDtos.UserResponse setStatus(Long id, boolean active) {
        User user = userRepository.findById(id).orElseThrow(() -> new ApiException("User not found"));
        user.setActive(active);
        return toResponse(userRepository.save(user));
    }

    private UserDtos.UserResponse toResponse(User user) {
        UserDtos.UserResponse resp = new UserDtos.UserResponse();
        resp.setId(user.getId());
        resp.setEmail(user.getEmail());
        resp.setFullName(user.getFullName());
        resp.setActive(user.isActive());
        resp.setRoles(user.getRoles().stream().map(Role::getName).collect(Collectors.toList()));
        return resp;
    }
}
