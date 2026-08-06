package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PayrollRun;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PayrollRunRepository extends JpaRepository<PayrollRun, Long> {
    List<PayrollRun> findAllByActiveTrue(Sort sort);
}
