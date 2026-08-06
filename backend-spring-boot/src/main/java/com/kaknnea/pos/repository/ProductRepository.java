package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Product;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ProductRepository extends JpaRepository<Product, Long> {
        java.util.Optional<Product> findFirstBySku(String sku);

        @Query("""
                        select p from Product p
                        where (
                          lower(p.nameEn) like lower(concat('%', :q, '%'))
                          or lower(p.nameKm) like lower(concat('%', :q, '%'))
                          or lower(p.sku) like lower(concat('%', :q, '%'))
                          or lower(p.barcode) like lower(concat('%', :q, '%'))
                        )
                        and (:categoryId is null or p.category.id = :categoryId)
                        and (:active is null or p.active = :active)
                        and (:sellable is null or p.sellable = :sellable)
                        and (:stockTracked is null or p.trackInventory = :stockTracked)
                        and (:purchasable is null or p.purchasable = :purchasable)
                        and (:productType is null or p.productType = :productType)
                        """)
        Page<Product> search(
                        @Param("q") String q,
                        @Param("categoryId") Long categoryId,
                        @Param("active") Boolean active,
                        @Param("sellable") Boolean sellable,
                        @Param("stockTracked") Boolean stockTracked,
                        @Param("purchasable") Boolean purchasable,
                        @Param("productType") String productType,
                        Pageable pageable);

        java.util.List<Product> findAllByModifierGroups_Id(Long groupId);

        List<Product> findAllByActiveTrueAndSellableTrueOrderByNameEnAsc();

        List<Product> findAllByActiveTrueAndTrackInventoryTrueOrderByNameEnAsc();

        Optional<Product> findByBarcode(String barcode);

        List<Product> findAllByActiveTrueAndPurchasableTrueOrderByNameEnAsc();

        long countBySaleUnitIdOrPurchaseUnitIdOrStockUnitId(Long saleUnitId, Long purchaseUnitId, Long stockUnitId);
}
