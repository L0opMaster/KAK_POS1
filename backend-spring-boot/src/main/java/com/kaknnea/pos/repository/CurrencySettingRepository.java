package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.CurrencySetting;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CurrencySettingRepository extends JpaRepository<CurrencySetting, Long> {
    Optional<CurrencySetting> findByCode(String code);
    boolean existsByCodeAndIdNot(String code, Long id);

    @Query("""
            select c from CurrencySetting c
            where (:q = '' or lower(c.code) like lower(concat('%', :q, '%'))
                or lower(c.name) like lower(concat('%', :q, '%'))
                or lower(c.symbol) like lower(concat('%', :q, '%')))
              and (:active is null or c.active = :active)
            """)
    Page<CurrencySetting> search(@Param("q") String q, @Param("active") Boolean active, Pageable pageable);
}
