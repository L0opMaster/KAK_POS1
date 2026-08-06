package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.StockTransfer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface StockTransferRepository extends JpaRepository<StockTransfer, Long> {
    /** Replaces unbounded findAll() in list(). Returns the 200 most recent transfers. */
    List<StockTransfer> findTop200ByOrderByIdDesc();

    @Query("""
            select transfer.status, line.quantity, concat('Transfer #', transfer.id), transfer.createdAt
            from StockTransfer transfer
            join transfer.lines line
            where line.product.id = :productId
            order by transfer.createdAt desc, transfer.id desc
            """)
    List<Object[]> findProductHistoryRows(Long productId);
}
