package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Purchase;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PurchaseRepository extends JpaRepository<Purchase, Long> {
    @Query("""
            select p.status, line.quantity, concat('Purchase #', p.id), p.createdAt
            from Purchase p
            join p.lines line
            where line.product.id = :productId
            order by p.createdAt desc, p.id desc
            """)
    List<Object[]> findProductHistoryRows(Long productId);
}
