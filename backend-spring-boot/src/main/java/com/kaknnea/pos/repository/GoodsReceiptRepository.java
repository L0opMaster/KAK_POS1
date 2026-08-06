package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.GoodsReceipt;
import java.time.Instant;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface GoodsReceiptRepository extends JpaRepository<GoodsReceipt, Long> {
    boolean existsByLinesProductId(Long productId);

    @Query("""
            select gr from GoodsReceipt gr
            join fetch gr.supplier
            join fetch gr.store
            where ((gr.receivedAt is not null and gr.receivedAt >= :start and gr.receivedAt < :end)
                or (gr.receivedAt is null and gr.createdAt >= :start and gr.createdAt < :end))
            order by gr.receivedAt asc, gr.id asc
            """)
    List<GoodsReceipt> findReportReceipts(Instant start, Instant end);

    @Query("""
            select gr.status, line.receivedQuantity, concat('Goods receipt #', gr.id), gr.createdAt
            from GoodsReceipt gr
            join gr.lines line
            where line.product.id = :productId
            order by gr.createdAt desc, gr.id desc
            """)
    List<Object[]> findProductHistoryRows(Long productId);
}
