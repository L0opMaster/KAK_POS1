package com.kaknnea.pos.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {
    private final JwtAuthFilter jwtAuthFilter;

    @Value("${app.cors.allowed-origins:http://localhost:4200,http://localhost,http://localhost:3000,http://127.0.0.1:3000}")
    private String allowedOriginsRaw;

    /** Dev only: skip role checks — every authenticated request is permitted. */
    @Value("${app.security.permit-all:false}")
    private boolean devPermitAll;

    /** Dev only: disable JWT validation — no token required at all. */
    @Value("${app.dev.disable-auth:false}")
    private boolean devDisableAuth;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http.cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS));

        if (devDisableAuth) {
            // DEV ONLY: no token required — permit every request and bypass @PreAuthorize
            http.authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
            http.addFilterBefore(new OncePerRequestFilter() {
                @Override
                protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
                        throws ServletException, IOException {
                    if (SecurityContextHolder.getContext().getAuthentication() == null) {
                        var auth = new UsernamePasswordAuthenticationToken(
                                "dev-user", null,
                                List.of(new SimpleGrantedAuthority("ROLE_OWNER"),
                                        new SimpleGrantedAuthority("PERM_PRODUCT_MANAGE"),
                                        new SimpleGrantedAuthority("PERM_POS_SALE")));
                        SecurityContextHolder.getContext().setAuthentication(auth);
                    }
                    chain.doFilter(req, res);
                }
            }, UsernamePasswordAuthenticationFilter.class);
        } else if (devPermitAll) {
            // DEV ONLY: token still required but role checks are skipped
            http.authorizeHttpRequests(auth -> auth
                    .requestMatchers("/auth/**", "/api/auth/**", "/swagger/**", "/api-docs/**",
                            "/actuator/health", "/media/**", "/api/settings/public/**").permitAll()
                    .requestMatchers("/ws/**").permitAll()
                    .anyRequest().authenticated());
            http.addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        } else {
            // PRODUCTION: full role enforcement
            http.authorizeHttpRequests(auth -> auth
                    // Permit both /auth/... and /api/auth/... since frontend may call either path
                    .requestMatchers("/auth/**", "/api/auth/**", "/swagger/**", "/api-docs/**",
                            "/actuator/health", "/media/**", "/api/settings/public/**", "/ws/**").permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/products/**", "/api/categories/**")
                    .hasAnyRole("OWNER", "MANAGER", "CASHIER", "ACCOUNTANT", "ADMIN")
                    .anyRequest().authenticated());
            http.addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        }

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();

        boolean wildcardCors = "*".equals(allowedOriginsRaw.trim());
        if (wildcardCors) {
            // Dev mode: allow every origin via pattern (required when credentials=true)
            config.setAllowedOriginPatterns(List.of("*"));
        } else {
            List<String> origins = Arrays.stream(allowedOriginsRaw.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .toList();
            config.setAllowedOrigins(origins);
            // Also allow origin patterns for any localhost port (helps with dev servers)
            config.setAllowedOriginPatterns(List.of("http://localhost:*", "http://127.0.0.1:*"));
        }

        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        config.setExposedHeaders(List.of("Authorization"));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
