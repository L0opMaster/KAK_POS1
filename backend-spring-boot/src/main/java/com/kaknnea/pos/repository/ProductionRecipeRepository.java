package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.ProductionRecipe;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductionRecipeRepository extends JpaRepository<ProductionRecipe, Long> {
    boolean existsByOutputProductIdAndNameIgnoreCase(Long outputProductId, String name);
}
