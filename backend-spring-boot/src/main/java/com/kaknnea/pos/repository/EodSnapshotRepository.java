package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.EodSnapshot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;

@Repository
public interface EodSnapshotRepository extends JpaRepository<EodSnapshot, Long> {

    Optional<EodSnapshot> findByEodDate(LocalDate eodDate);

    @Query("SELECT e FROM EodSnapshot e WHERE e.eodDate = :date AND e.status = 'COMPLETED'")
    Optional<EodSnapshot> findCompletedByDate(@Param("date") LocalDate date);

    @Query("SELECT e FROM EodSnapshot e WHERE e.status = 'COMPLETED' ORDER BY e.eodDate DESC")
    Optional<EodSnapshot> findLatestCompleted();
}