package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.TicketOperationLog;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TicketOperationLogRepository extends JpaRepository<TicketOperationLog, Long> {
    Optional<TicketOperationLog> findFirstByActionAndIdempotencyKeyOrderByIdDesc(String action, String idempotencyKey);
}
