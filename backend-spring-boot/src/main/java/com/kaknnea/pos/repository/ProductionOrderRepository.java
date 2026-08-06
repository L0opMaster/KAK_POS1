package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.ProductionOrder;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductionOrderRepository extends JpaRepository<ProductionOrder, Long> {
}
