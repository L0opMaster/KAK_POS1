package com.kaknnea.pos.repository;
import com.kaknnea.pos.domain.CustomerAdjustment;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
public interface CustomerAdjustmentRepository extends JpaRepository<CustomerAdjustment, Long> {
    List<CustomerAdjustment> findByCustomerIdOrderByCreatedAtDesc(Long customerId);
}
