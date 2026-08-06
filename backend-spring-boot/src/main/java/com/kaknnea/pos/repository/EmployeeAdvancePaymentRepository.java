package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.EmployeeAdvancePayment;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface EmployeeAdvancePaymentRepository extends JpaRepository<EmployeeAdvancePayment, Long> {
    List<EmployeeAdvancePayment> findAllByAdvanceId(Long advanceId, Sort sort);
}
