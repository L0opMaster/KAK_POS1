package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Shift;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ShiftRepository extends JpaRepository<Shift, Long> {
    Optional<Shift> findFirstByOpenedByIdAndStatusOrderByOpenedAtDesc(Long openedById, String status);
    Optional<Shift> findFirstByOpenedByIdAndStoreIdAndStatusOrderByOpenedAtDesc(Long openedById, Long storeId, String status);

    @EntityGraph(attributePaths = {"openedBy", "store"})
    List<Shift> findByOpenedAtGreaterThanEqualAndOpenedAtLessThanOrderByOpenedAtAsc(Instant start, Instant end);

    @EntityGraph(attributePaths = {"openedBy", "store"})
    @Query("""
            select s from Shift s
            where s.closedAt >= :start
              and s.closedAt < :end
              and s.variance is not null
              and s.variance <> 0
            order by s.closedAt desc
            """)
    List<Shift> findCashAdjustmentShifts(Instant start, Instant end);
}
