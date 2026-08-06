package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.RecurringInvoiceTemplate;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface RecurringInvoiceTemplateRepository extends JpaRepository<RecurringInvoiceTemplate, Long> {

    List<RecurringInvoiceTemplate> findByActiveTrueAndNextRunDateLessThanEqual(LocalDate date);

    List<RecurringInvoiceTemplate> findByActiveTrueOrderByNextRunDateAsc();
}
