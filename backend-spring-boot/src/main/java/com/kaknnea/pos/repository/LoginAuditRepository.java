package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.LoginAudit;
import java.time.Instant;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface LoginAuditRepository extends JpaRepository<LoginAudit, Long> {
    @EntityGraph(attributePaths = {"user"})
    List<LoginAudit> findTop500ByOrderByCreatedAtDesc();

    @EntityGraph(attributePaths = {"user"})
    List<LoginAudit> findTop500ByCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(Instant start, Instant end);
}
