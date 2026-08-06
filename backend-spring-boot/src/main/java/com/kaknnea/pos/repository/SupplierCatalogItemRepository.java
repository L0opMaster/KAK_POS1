package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.SupplierCatalogItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface SupplierCatalogItemRepository extends JpaRepository<SupplierCatalogItem, Long> {
    List<SupplierCatalogItem> findAllBySupplierIdOrderByCreatedAtDesc(Long supplierId);

    long countBySupplierId(Long supplierId);
    long countByPurchaseUnitId(Long purchaseUnitId);

    @Query("""
            select item.supplier.id, count(item)
            from SupplierCatalogItem item
            group by item.supplier.id
            """)
    List<Object[]> summarizeCountsBySupplier();

    void deleteAllBySupplierId(Long supplierId);
}
