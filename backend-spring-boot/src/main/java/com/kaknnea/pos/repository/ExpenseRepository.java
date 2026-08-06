package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Expense;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface ExpenseRepository extends JpaRepository<Expense, Long> {

    List<Expense> findAllByActiveTrue(Sort sort);

    List<Expense> findAllByActiveTrueAndExpenseDateBetween(LocalDate from, LocalDate to, Sort sort);

    List<Expense> findAllByActiveTrueAndCategoryId(Long categoryId, Sort sort);

    List<Expense> findAllByActiveTrueAndStatus(String status, Sort sort);

    List<Expense> findAllByActiveTrueAndExpenseDateBetweenAndStatus(LocalDate from, LocalDate to, String status, Sort sort);

    @Query("SELECT COALESCE(SUM(e.amount), 0) FROM Expense e WHERE e.active = true AND e.expenseDate BETWEEN :from AND :to")
    BigDecimal sumAmountByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    @Query("SELECT COALESCE(SUM(e.amount), 0) FROM Expense e WHERE e.active = true AND e.expenseDate BETWEEN :from AND :to AND e.status = :status")
    BigDecimal sumAmountByDateRangeAndStatus(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("status") String status);

    @Query("SELECT COUNT(e) FROM Expense e WHERE e.active = true AND e.status = :status")
    long countByStatus(@Param("status") String status);
}
