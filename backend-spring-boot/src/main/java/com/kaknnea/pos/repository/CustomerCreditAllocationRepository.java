package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.CustomerCreditAllocation;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CustomerCreditAllocationRepository extends JpaRepository<CustomerCreditAllocation, Long> {
    List<CustomerCreditAllocation> findByCustomerIdOrderByCreatedAtDesc(Long customerId);
    List<CustomerCreditAllocation> findByPaymentIdOrderByCreatedAtAsc(Long paymentId);
}
