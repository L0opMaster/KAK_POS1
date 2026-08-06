package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.InventorySnapshot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDate;
import java.util.List;

public interface InventorySnapshotRepository extends JpaRepository<InventorySnapshot, Long> {
    @EntityGraph(attributePaths = {"product", "store"})
    List<InventorySnapshot> findAllBySnapshotDateAndStoreIdOrderByProduct_NameEnAsc(LocalDate snapshotDate, Long storeId);

    @Override
    @EntityGraph(attributePaths = {"product", "store"})
    java.util.Optional<InventorySnapshot> findById(Long id);

    @EntityGraph(attributePaths = {"product", "store"})
    List<InventorySnapshot> findTop500ByOrderByCreatedAtDesc();

    @EntityGraph(attributePaths = {"product", "store"})
    List<InventorySnapshot> findTop500BySnapshotDateBetweenOrderByCreatedAtDesc(LocalDate from, LocalDate to);

    @Query("""
            select snapshot.countStatus, snapshot.varianceQuantity, snapshot.notes, snapshot.postedAt
            from InventorySnapshot snapshot
            where snapshot.product.id = :productId
              and snapshot.postedAt is not null
            order by snapshot.postedAt desc, snapshot.id desc
            """)
    List<Object[]> findProductHistoryRows(Long productId);

    boolean existsBySnapshotDateAndStoreId(LocalDate snapshotDate, Long storeId);
}
