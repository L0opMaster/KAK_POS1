package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.DeliveryNote;
import java.util.Collection;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DeliveryNoteRepository extends JpaRepository<DeliveryNote, Long> {
    Optional<DeliveryNote> findTopByOrderByIdDesc();
    boolean existsBySaleIdAndStatusIn(Long saleId, Collection<String> statuses);
    boolean existsBySaleIdAndStatusInAndIdNot(Long saleId, Collection<String> statuses, Long id);
}
