package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Payment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {

    // Legacy methods
    @Query("select coalesce(sum(p.amount),0) from Payment p where p.method = :method and p.createdAt >= :from")
    BigDecimal sumByMethodSince(@Param("method") String method, @Param("from") LocalDateTime from);

    long countBySaleId(Long saleId);

    List<Payment> findBySaleIdOrderByCreatedAtAscIdAsc(Long saleId);

    @Query("select coalesce(sum(p.amount),0) from Payment p where p.shift.id = :shiftId and upper(p.method) = upper(:method)")
    BigDecimal sumByShiftIdAndMethod(@Param("shiftId") Long shiftId, @Param("method") String method);

    // New Cart-based payment methods
    Optional<Payment> findByCartId(Long cartId);

    Optional<Payment> findByReferenceNumber(String referenceNumber);

    @Query("""
            SELECT p
            FROM Payment p
            LEFT JOIN p.sale s
            WHERE p.customer.id = :customerId OR s.customer.id = :customerId
            """)
    List<Payment> findByCustomerOrSaleCustomerId(@Param("customerId") Long customerId);

    @Query("""
            SELECT p
            FROM Payment p
            LEFT JOIN p.sale s
            WHERE (p.customer.id = :customerId OR s.customer.id = :customerId)
              AND p.status = :status
            ORDER BY p.createdAt DESC, p.id DESC
            """)
    List<Payment> findCustomerOrSaleCustomerPaymentsByStatus(
            @Param("customerId") Long customerId,
            @Param("status") Payment.PaymentStatus status);

    List<Payment> findByStoreId(Long storeId);

    List<Payment> findByStatus(Payment.PaymentStatus status);

    List<Payment> findAllByOrderByCreatedAtDescIdDesc();

    List<Payment> findByCreatedAtBetweenOrderByCreatedAtDescIdDesc(LocalDateTime startDate, LocalDateTime endDate);

    @Query("SELECT p FROM Payment p WHERE p.status = :status AND p.createdAt >= :startDate AND p.createdAt <= :endDate")
    List<Payment> findByStatusAndDateRange(Payment.PaymentStatus status, LocalDateTime startDate,
            LocalDateTime endDate);

    @Query("""
            SELECT p
            FROM Payment p
            LEFT JOIN FETCH p.sale s
            LEFT JOIN FETCH s.customer
            LEFT JOIN FETCH s.shift ss
            LEFT JOIN FETCH ss.store
            LEFT JOIN FETCH p.customer
            LEFT JOIN FETCH p.store
            LEFT JOIN FETCH p.shift sh
            LEFT JOIN FETCH sh.store
            WHERE p.status = :status
              AND p.createdAt >= :startDate
              AND p.createdAt < :endDate
            ORDER BY p.createdAt DESC, p.id DESC
            """)
    List<Payment> findReportPayments(
            @Param("status") Payment.PaymentStatus status,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate);

    @Query("SELECT p FROM Payment p WHERE p.customer.id = :customerId AND p.createdAt >= :startDate ORDER BY p.createdAt DESC")
    List<Payment> findCustomerPaymentsAfterDate(Long customerId, LocalDateTime startDate);

    long countByStatus(Payment.PaymentStatus status);

    @Query("SELECT COUNT(p) FROM Payment p WHERE p.status = :status AND p.createdAt >= :startDate AND p.createdAt <= :endDate")
    long countByStatusAndDateRange(Payment.PaymentStatus status, LocalDateTime startDate, LocalDateTime endDate);
}
