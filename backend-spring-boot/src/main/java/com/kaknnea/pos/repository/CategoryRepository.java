package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Category;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CategoryRepository extends JpaRepository<Category, Long> {
    java.util.Optional<Category> findFirstByNameEnIgnoreCase(String nameEn);
}
