package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.CustomerCreditOpeningBalance;
import java.util.List;
import java.util.Optional;
import java.math.BigDecimal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

public interface CustomerCreditOpeningBalanceRepository extends JpaRepository<CustomerCreditOpeningBalance, Long> {
    boolean existsByCustomerId(Long customerId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select o from CustomerCreditOpeningBalance o where o.id = :id")
    Optional<CustomerCreditOpeningBalance> findByIdForUpdate(@Param("id") Long id);

    List<CustomerCreditOpeningBalance> findByCustomerIdOrderByCreatedAtAsc(Long customerId);

    List<CustomerCreditOpeningBalance> findByCustomerIdAndRemainingAmountGreaterThanOrderByCreatedAtAsc(
            Long customerId,
            java.math.BigDecimal remainingAmount);

    @Query("select coalesce(sum(o.originalAmount), 0) from CustomerCreditOpeningBalance o where o.customer.id = :customerId")
    BigDecimal sumOriginalAmountByCustomerId(@Param("customerId") Long customerId);
}
