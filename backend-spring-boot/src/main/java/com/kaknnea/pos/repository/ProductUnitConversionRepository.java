package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.ProductUnitConversion;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ProductUnitConversionRepository extends JpaRepository<ProductUnitConversion, Long> {
    List<ProductUnitConversion> findBySourceProductIdOrTargetProductId(Long sourceProductId, Long targetProductId);
    boolean existsBySourceProductIdAndTargetProductIdAndSourceUnitIdAndTargetUnitIdAndConversionType(
            Long sourceProductId,
            Long targetProductId,
            Long sourceUnitId,
            Long targetUnitId,
            String conversionType);
}
