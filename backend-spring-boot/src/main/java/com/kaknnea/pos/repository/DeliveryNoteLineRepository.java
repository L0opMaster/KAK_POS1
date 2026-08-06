package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.DeliveryNoteLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface DeliveryNoteLineRepository extends JpaRepository<DeliveryNoteLine, Long> {
    void deleteBySaleLineId(Long saleLineId);
}
