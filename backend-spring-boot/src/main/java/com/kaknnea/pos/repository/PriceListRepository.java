package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PriceList;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;

public interface PriceListRepository extends JpaRepository<PriceList, Long> {
    List<PriceList> findAllByActiveTrueOrderByPriorityDescNameAsc();

    default List<PriceList> findEffectiveLists(Instant now) {
        return findAllByActiveTrueOrderByPriorityDescNameAsc().stream()
                .filter(priceList -> (priceList.getStartsAt() == null || !priceList.getStartsAt().isAfter(now))
                        && (priceList.getEndsAt() == null || !priceList.getEndsAt().isBefore(now)))
                .toList();
    }
}
