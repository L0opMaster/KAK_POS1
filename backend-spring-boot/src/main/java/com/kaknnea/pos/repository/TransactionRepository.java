package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Transaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    List<Transaction> findByPaymentId(Long paymentId);

    Optional<Transaction> findByGatewayTransactionId(String gatewayTransactionId);

    List<Transaction> findByTransactionType(Transaction.TransactionType transactionType);

    List<Transaction> findByStatus(Transaction.TransactionStatus status);

    @Query("SELECT t FROM Transaction t WHERE t.payment.id = :paymentId AND t.transactionType = :transactionType ORDER BY t.transactionDate DESC")
    List<Transaction> findPaymentTransactionsByType(Long paymentId, Transaction.TransactionType transactionType);

    @Query("SELECT t FROM Transaction t WHERE t.status = :status AND t.transactionDate >= :startDate AND t.transactionDate <= :endDate")
    List<Transaction> findByStatusAndDateRange(Transaction.TransactionStatus status, LocalDateTime startDate,
            LocalDateTime endDate);

    @Query("SELECT t FROM Transaction t WHERE t.payment.id = :paymentId ORDER BY t.transactionDate DESC")
    List<Transaction> findPaymentTransactionHistory(Long paymentId);

    long countByStatus(Transaction.TransactionStatus status);

    @Query("SELECT COUNT(t) FROM Transaction t WHERE t.status = :status AND t.transactionDate >= :startDate AND t.transactionDate <= :endDate")
    long countByStatusAndDateRange(Transaction.TransactionStatus status, LocalDateTime startDate,
            LocalDateTime endDate);
}
