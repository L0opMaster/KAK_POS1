package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.CashEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;

public interface CashEventRepository extends JpaRepository<CashEvent, Long> {
    List<CashEvent> findByShiftIdOrderByCreatedAtDesc(Long shiftId);

    @Query("select coalesce(sum(c.amount),0) from CashEvent c where c.shift.id = :shiftId and c.type in :types")
    BigDecimal sumByShiftIdAndTypes(@Param("shiftId") Long shiftId, @Param("types") List<String> types);
}
