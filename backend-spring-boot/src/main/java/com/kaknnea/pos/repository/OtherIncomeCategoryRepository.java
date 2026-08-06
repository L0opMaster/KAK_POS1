package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.OtherIncomeCategory;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface OtherIncomeCategoryRepository extends JpaRepository<OtherIncomeCategory, Long> {
    List<OtherIncomeCategory> findAllByActiveOrderByNameEnAsc(boolean active);
    List<OtherIncomeCategory> findAllByOrderByNameEnAsc();
}
