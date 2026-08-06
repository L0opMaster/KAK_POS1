package com.kaknnea.pos.controller;

import com.kaknnea.pos.domain.PaymentMethod;
import com.kaknnea.pos.repository.PaymentMethodRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/payment-methods")
public class PaymentMethodController {

    private final PaymentMethodRepository paymentMethodRepository;

    public PaymentMethodController(PaymentMethodRepository paymentMethodRepository) {
        this.paymentMethodRepository = paymentMethodRepository;
    }

    @GetMapping("/active")
    @PreAuthorize("permitAll")
    public ResponseEntity<List<PaymentMethod>> getActiveMethods() {
        List<PaymentMethod> methods = paymentMethodRepository.findAllByOrderByDisplayOrderAscNameAsc()
                .stream()
                .filter(PaymentMethod::isActive)
                .toList();
        return ResponseEntity.ok(methods);
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public ResponseEntity<List<PaymentMethod>> getAll() {
        return ResponseEntity.ok(paymentMethodRepository.findAllByOrderByDisplayOrderAscNameAsc());
    }
}
