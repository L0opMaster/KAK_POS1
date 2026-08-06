package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PurchaseOrder;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;

public interface PurchaseOrderRepository extends JpaRepository<PurchaseOrder, Long>, JpaSpecificationExecutor<PurchaseOrder> {
    long countByStatus(String status);

    long countByStatusIn(Collection<String> statuses);

    @Query("""
            select po.supplier.id, max(po.orderedAt)
            from PurchaseOrder po
            where po.orderedAt is not null
            group by po.supplier.id
            """)
    List<Object[]> summarizeLatestOrderedAtBySupplier();

    @Query("""
            select max(po.orderedAt)
            from PurchaseOrder po
            where po.supplier.id = :supplierId
              and po.orderedAt is not null
            """)
    Instant findLatestOrderedAtBySupplierId(Long supplierId);

    @Query("""
            select po from PurchaseOrder po
            join fetch po.supplier
            join fetch po.store
            where ((po.orderedAt is not null and po.orderedAt >= :start and po.orderedAt < :end)
                or (po.orderedAt is null and po.createdAt >= :start and po.createdAt < :end))
            order by po.orderedAt asc, po.id asc
            """)
    List<PurchaseOrder> findReportOrders(Instant start, Instant end);
}
