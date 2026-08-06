package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.EmployeeExpense;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface EmployeeExpenseRepository extends JpaRepository<EmployeeExpense, Long> {
    List<EmployeeExpense> findAllByActiveTrue(Sort sort);
    List<EmployeeExpense> findAllByActiveTrueAndEmployeeId(Long employeeId, Sort sort);
    List<EmployeeExpense> findAllByActiveTrueAndStatus(String status, Sort sort);
}
