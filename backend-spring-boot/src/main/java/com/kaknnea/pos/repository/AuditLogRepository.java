package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.AuditLog;
import java.time.Instant;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {
    @EntityGraph(attributePaths = {"actor"})
    List<AuditLog> findTop500ByOrderByCreatedAtDesc();

    @EntityGraph(attributePaths = {"actor"})
    List<AuditLog> findTop500ByCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(Instant start, Instant end);
}
