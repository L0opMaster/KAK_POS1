package com.kaknnea.pos.security;

import com.kaknnea.pos.domain.Permission;
import com.kaknnea.pos.repository.PermissionRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.LinkedHashSet;
import java.util.stream.Collectors;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {
    private static final Logger log = LoggerFactory.getLogger(JwtAuthFilter.class);

    private final JwtUtil jwtUtil;
    private final PermissionRepository permissionRepository;

    /** Dev only: when true every authenticated user receives all permissions,
     *  bypassing @PreAuthorize method-level checks as well as URL-level role checks. */
    @Value("${app.security.permit-all:false}")
    private boolean devPermitAll;

    public JwtAuthFilter(JwtUtil jwtUtil, PermissionRepository permissionRepository) {
        this.jwtUtil = jwtUtil;
        this.permissionRepository = permissionRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                JwtUtil.JwtUser jwtUser = jwtUtil.parse(token);
                var authorities = new LinkedHashSet<>(jwtUser.roles().stream()
                        .map(r -> r.startsWith("ROLE_") ? r : "ROLE_" + r)
                        .map(SimpleGrantedAuthority::new)
                        .collect(Collectors.toSet()));
                if (jwtUser.permissions() != null) {
                    authorities.addAll(jwtUser.permissions().stream()
                            .map(p -> new SimpleGrantedAuthority(p.startsWith("PERM_") ? p : "PERM_" + p))
                            .collect(Collectors.toSet()));
                }
                // Grant all permissions when running in dev permit-all mode OR for elevated admin roles.
                // This ensures @PreAuthorize method-level checks are also bypassed in dev mode.
                boolean isElevated = jwtUser.roles() != null &&
                        jwtUser.roles().stream().anyMatch(role ->
                                "OWNER".equals(role) || "ADMIN".equals(role) || "SYSTEM_ADMIN".equals(role));
                if (devPermitAll || isElevated) {
                    authorities.addAll(permissionRepository.findAll().stream()
                            .map(Permission::getName)
                            .map(p -> new SimpleGrantedAuthority(p.startsWith("PERM_") ? p : "PERM_" + p))
                            .collect(Collectors.toSet()));
                }
                if (log.isDebugEnabled()) {
                    log.debug("JWT auth success for user {} on {} with roles={} perms={}",
                            jwtUser.email(), request.getMethod() + " " + request.getRequestURI(),
                            jwtUser.roles(), jwtUser.permissions());
                }
                var auth = new UsernamePasswordAuthenticationToken(jwtUser.email(), null, authorities);
                auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                SecurityContextHolder.getContext().setAuthentication(auth);
            } catch (Exception ex) {
                log.warn("Failed JWT validation for request {} {}: {}",
                        request.getMethod(), request.getRequestURI(), ex.getMessage());
                SecurityContextHolder.clearContext();
            }
        }
        filterChain.doFilter(request, response);
    }
}
