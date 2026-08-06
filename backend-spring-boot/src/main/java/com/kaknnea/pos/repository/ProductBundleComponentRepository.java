package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.ProductBundleComponent;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ProductBundleComponentRepository extends JpaRepository<ProductBundleComponent, Long> {
    List<ProductBundleComponent> findAllByBundleProductId(Long bundleProductId);
}
