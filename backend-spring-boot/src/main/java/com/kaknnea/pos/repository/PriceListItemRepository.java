package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PriceListItem;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PriceListItemRepository extends JpaRepository<PriceListItem, Long> {
    List<PriceListItem> findAllByPriceListId(Long priceListId);
    Optional<PriceListItem> findFirstByPriceListIdAndProductId(Long priceListId, Long productId);
}
