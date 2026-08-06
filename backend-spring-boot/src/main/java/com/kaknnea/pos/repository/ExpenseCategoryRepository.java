package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.ExpenseCategory;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ExpenseCategoryRepository extends JpaRepository<ExpenseCategory, Long> {
    List<ExpenseCategory> findAllByActiveOrderByNameEnAsc(boolean active);
    List<ExpenseCategory> findAllByOrderByNameEnAsc();
}
