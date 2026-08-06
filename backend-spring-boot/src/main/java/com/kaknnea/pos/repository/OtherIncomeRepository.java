package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.OtherIncome;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface OtherIncomeRepository extends JpaRepository<OtherIncome, Long> {
    List<OtherIncome> findAllByActiveTrue(Sort sort);
    List<OtherIncome> findAllByActiveTrueAndIncomeDateBetween(LocalDate from, LocalDate to, Sort sort);
    List<OtherIncome> findAllByActiveTrueAndCategoryId(Long categoryId, Sort sort);
    List<OtherIncome> findAllByActiveTrueAndStatus(String status, Sort sort);
    List<OtherIncome> findAllByActiveTrueAndIncomeDateBetweenAndStatus(LocalDate from, LocalDate to, String status, Sort sort);

    @Query("SELECT COALESCE(SUM(i.amount), 0) FROM OtherIncome i WHERE i.active = true AND i.incomeDate BETWEEN :from AND :to")
    BigDecimal sumAmountByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    @Query("SELECT COUNT(i) FROM OtherIncome i WHERE i.active = true AND i.status = :status")
    long countByStatus(@Param("status") String status);
}
