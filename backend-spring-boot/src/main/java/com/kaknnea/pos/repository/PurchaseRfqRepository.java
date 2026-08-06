package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PurchaseRfq;
import java.util.Collection;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PurchaseRfqRepository extends JpaRepository<PurchaseRfq, Long> {
    long countByStatusIn(Collection<String> statuses);

    long countByStatus(String status);
}
