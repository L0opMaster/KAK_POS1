package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.EmployeeAdvance;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface EmployeeAdvanceRepository extends JpaRepository<EmployeeAdvance, Long> {
    List<EmployeeAdvance> findAllByActiveTrue(Sort sort);
    List<EmployeeAdvance> findAllByActiveTrueAndEmployeeId(Long employeeId, Sort sort);
    List<EmployeeAdvance> findAllByActiveTrueAndStatus(String status, Sort sort);
}
