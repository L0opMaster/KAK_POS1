package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.PaymentDtos;
import com.kaknnea.pos.service.PaymentService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;

@Slf4j
@RestController
@RequestMapping("/api/payments")
@PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
public class PaymentController {

    @Autowired
    private PaymentService paymentService;

    @GetMapping
    public ResponseEntity<PaymentDtos.PaymentListResponse> getPayments(
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to) {
        try {
            LocalDateTime fromDate = parseDateTime(from);
            LocalDateTime toDate = parseDateTime(to);
            return ResponseEntity.ok(paymentService.getPayments(fromDate, toDate));
        } catch (Exception e) {
            log.error("Error fetching payments", e);
            throw new RuntimeException("Failed to fetch payments: " + e.getMessage());
        }
    }

    /**
     * Create a new payment for a cart
     */
    @PostMapping
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER')")
    public ResponseEntity<PaymentDtos.PaymentResponse> createPayment(
            @RequestBody PaymentDtos.CreatePaymentRequest request) {
        try {
            log.info("Creating payment for cart: {}", request.getCartId());
            PaymentDtos.PaymentResponse response = paymentService.createPayment(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (Exception e) {
            log.error("Error creating payment", e);
            throw new RuntimeException("Failed to create payment: " + e.getMessage());
        }
    }

    /**
     * Get payment by ID
     */
    @GetMapping("/{id}")
    public ResponseEntity<PaymentDtos.PaymentResponse> getPayment(@PathVariable Long id) {
        try {
            log.info("Fetching payment: {}", id);
            PaymentDtos.PaymentResponse response = paymentService.getPayment(id);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error fetching payment", e);
            throw new RuntimeException("Failed to fetch payment: " + e.getMessage());
        }
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('MANAGER', 'OWNER')")
    public ResponseEntity<PaymentDtos.PaymentResponse> updatePayment(
            @PathVariable Long id,
            @RequestBody PaymentDtos.UpdatePaymentRequest request) {
        try {
            log.info("Updating payment: {}", id);
            PaymentDtos.PaymentResponse response = paymentService.updatePayment(id, request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error updating payment", e);
            throw new RuntimeException("Failed to update payment: " + e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('MANAGER', 'OWNER')")
    public ResponseEntity<PaymentDtos.PaymentResponse> deletePayment(
            @PathVariable Long id,
            @RequestParam(required = false) String reason) {
        try {
            log.info("Deleting payment: {}", id);
            PaymentDtos.PaymentResponse response = paymentService.deletePayment(id, reason);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error deleting payment", e);
            throw new RuntimeException("Failed to delete payment: " + e.getMessage());
        }
    }

    /**
     * Get payment by cart ID
     */
    @GetMapping("/cart/{cartId}")
    public ResponseEntity<PaymentDtos.PaymentResponse> getPaymentByCart(@PathVariable Long cartId) {
        try {
            log.info("Fetching payment for cart: {}", cartId);
            PaymentDtos.PaymentResponse response = paymentService.getPaymentByCart(cartId);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error fetching payment by cart", e);
            throw new RuntimeException("Failed to fetch payment: " + e.getMessage());
        }
    }

    /**
     * Get payment status
     */
    @GetMapping("/{id}/status")
    public ResponseEntity<PaymentDtos.PaymentStatusResponse> getPaymentStatus(@PathVariable Long id) {
        try {
            log.info("Fetching payment status: {}", id);
            PaymentDtos.PaymentStatusResponse response = paymentService.getPaymentStatus(id);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error fetching payment status", e);
            throw new RuntimeException("Failed to fetch payment status: " + e.getMessage());
        }
    }

    /**
     * Process payment (authorize and capture)
     */
    @PostMapping("/{id}/process")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER')")
    public ResponseEntity<PaymentDtos.PaymentResponse> processPayment(
            @PathVariable Long id,
            @RequestBody PaymentDtos.ProcessPaymentRequest request) {
        try {
            request.setPaymentId(id);
            log.info("Processing payment: {}", id);
            PaymentDtos.PaymentResponse response = paymentService.processPayment(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error processing payment", e);
            throw new RuntimeException("Failed to process payment: " + e.getMessage());
        }
    }

    /**
     * Refund payment
     */
    @PostMapping("/{id}/refund")
    @PreAuthorize("hasAnyRole('MANAGER', 'OWNER')")
    public ResponseEntity<PaymentDtos.PaymentResponse> refundPayment(
            @PathVariable Long id,
            @RequestBody PaymentDtos.RefundPaymentRequest request) {
        try {
            request.setPaymentId(id);
            log.info("Refunding payment: {}", id);
            PaymentDtos.PaymentResponse response = paymentService.refundPayment(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error refunding payment", e);
            throw new RuntimeException("Failed to refund payment: " + e.getMessage());
        }
    }

    /**
     * Get customer payments
     */
    @GetMapping("/customer/{customerId}")
    public ResponseEntity<PaymentDtos.PaymentListResponse> getCustomerPayments(
            @PathVariable Long customerId) {
        try {
            log.info("Fetching payments for customer: {}", customerId);
            PaymentDtos.PaymentListResponse response = paymentService.getCustomerPayments(customerId);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error fetching customer payments", e);
            throw new RuntimeException("Failed to fetch customer payments: " + e.getMessage());
        }
    }

    /**
     * Get daily payments
     */
    @GetMapping("/daily")
    @PreAuthorize("hasAnyRole('MANAGER', 'OWNER')")
    public ResponseEntity<PaymentDtos.PaymentListResponse> getDailyPayments() {
        try {
            log.info("Fetching daily payments");
            PaymentDtos.PaymentListResponse response = paymentService.getDailyPayments();
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error fetching daily payments", e);
            throw new RuntimeException("Failed to fetch daily payments: " + e.getMessage());
        }
    }

    private LocalDateTime parseDateTime(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return OffsetDateTime.parse(value).toLocalDateTime();
        } catch (Exception ignored) {
            return LocalDateTime.parse(value.replace("Z", ""));
        }
    }
}
