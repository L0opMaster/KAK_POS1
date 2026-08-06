package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Unit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface UnitRepository extends JpaRepository<Unit, Long> {
    Optional<Unit> findByCode(String code);
    boolean existsByCodeAndIdNot(String code, Long id);
    long countByBaseUnitId(Long baseUnitId);

    @Query("""
            select u from Unit u
            left join u.baseUnit base
            where (:q = '' or lower(u.code) like lower(concat('%', :q, '%'))
                or lower(u.nameEn) like lower(concat('%', :q, '%'))
                or lower(u.nameKm) like lower(concat('%', :q, '%'))
                or lower(u.name) like lower(concat('%', :q, '%'))
                or lower(u.symbol) like lower(concat('%', :q, '%'))
                or lower(u.baseUnitGroup) like lower(concat('%', :q, '%'))
                or lower(coalesce(base.code, '')) like lower(concat('%', :q, '%'))
                or lower(coalesce(base.nameEn, '')) like lower(concat('%', :q, '%'))
                or lower(coalesce(base.nameKm, '')) like lower(concat('%', :q, '%')))
              and (:active is null or u.active = :active)
            """)
    Page<Unit> search(@Param("q") String q, @Param("active") Boolean active, Pageable pageable);
}
