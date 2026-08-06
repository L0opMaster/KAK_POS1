package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PayrollLine;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PayrollLineRepository extends JpaRepository<PayrollLine, Long> {
    List<PayrollLine> findAllByPayrollRunId(Long payrollRunId);
    List<PayrollLine> findAllByEmployeeIdOrderByPayrollRunPayDateDesc(Long employeeId);
    void deleteAllByPayrollRunId(Long payrollRunId);
}
