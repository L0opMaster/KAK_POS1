package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.StockMovement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.List;

public interface StockMovementRepository extends JpaRepository<StockMovement, Long> {
    @EntityGraph(attributePaths = {"product", "store"})
    List<StockMovement> findAllByProductIdOrderByCreatedAtDesc(Long productId);

    @EntityGraph(attributePaths = {"product", "store"})
    List<StockMovement> findAllByStoreIdOrderByCreatedAtDesc(Long storeId);

    /** Replaces unbounded findAll() in movements(). Returns the 500 most recent movements across all stores. */
    @EntityGraph(attributePaths = {"product", "store"})
    List<StockMovement> findTop500ByOrderByCreatedAtDesc();

    @EntityGraph(attributePaths = {"product", "store"})
    List<StockMovement> findByCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(Instant start, Instant end);

    @EntityGraph(attributePaths = {"product", "store"})
    @Query("""
            select m from StockMovement m
            where m.createdAt >= :start
              and m.createdAt < :end
              and (
                lower(coalesce(m.movementType, '')) like '%adjust%'
                or lower(coalesce(m.movementType, '')) like '%correction%'
                or lower(coalesce(m.reason, '')) like '%adjust%'
                or lower(coalesce(m.reason, '')) like '%count%'
                or lower(coalesce(m.reason, '')) like '%damage%'
                or lower(coalesce(m.reason, '')) like '%variance%'
              )
            order by m.createdAt desc
            """)
    List<StockMovement> findAdjustmentAuditMovements(Instant start, Instant end);

    boolean existsByProductId(Long productId);
}
