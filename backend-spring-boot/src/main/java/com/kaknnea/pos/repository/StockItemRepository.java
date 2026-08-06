package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.StockItem;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import java.util.List;

public interface StockItemRepository extends JpaRepository<StockItem, Long> {
    @EntityGraph(attributePaths = {"product", "product.stockUnit", "store"})
    Optional<StockItem> findByProductIdAndStoreId(Long productId, Long storeId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @EntityGraph(attributePaths = {"product", "product.stockUnit", "store"})
    @Query("select s from StockItem s where s.product.id = :productId and s.store.id = :storeId")
    Optional<StockItem> findByProductIdAndStoreIdForUpdate(@Param("productId") Long productId, @Param("storeId") Long storeId);

    @EntityGraph(attributePaths = {"product", "product.stockUnit", "store"})
    List<StockItem> findAllByProductId(Long productId);

    @EntityGraph(attributePaths = {"product", "product.stockUnit", "store"})
    List<StockItem> findAllByStoreId(Long storeId);

    @Override
    @EntityGraph(attributePaths = {"product", "product.stockUnit", "store"})
    List<StockItem> findAll();

    @Query("""
            select s from StockItem s
            join fetch s.product p
            left join fetch p.stockUnit
            join fetch s.store
            where s.lowStockThreshold is not null
              and s.quantity <= s.lowStockThreshold
            order by s.quantity asc, s.id asc
            """)
    List<StockItem> findLowStockItems(Pageable pageable);

    @Query("""
            select s from StockItem s
            join fetch s.product p
            left join fetch p.stockUnit
            join fetch s.store
            order by p.nameEn asc, s.id asc
            """)
    List<StockItem> findStockCountFallbackRows(Pageable pageable);
}
