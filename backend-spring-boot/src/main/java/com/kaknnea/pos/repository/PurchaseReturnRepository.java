package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PurchaseReturn;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PurchaseReturnRepository extends JpaRepository<PurchaseReturn, Long> {
    @Query("""
            select r from PurchaseReturn r
            join fetch r.supplier
            order by r.createdAt desc, r.id desc
            """)
    List<PurchaseReturn> findRecentForLedger(Pageable pageable);
}
