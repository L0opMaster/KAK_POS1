package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PaymentMethod;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PaymentMethodRepository extends JpaRepository<PaymentMethod, Long> {
    Optional<PaymentMethod> findByCode(String code);
    boolean existsByCodeAndIdNot(String code, Long id);

    java.util.List<PaymentMethod> findAllByOrderByDisplayOrderAscNameAsc();

    @Query("""
            select p from PaymentMethod p
            where (:q = '' or lower(p.code) like lower(concat('%', :q, '%'))
                or lower(p.name) like lower(concat('%', :q, '%')))
              and (:active is null or p.active = :active)
            """)
    Page<PaymentMethod> search(@Param("q") String q, @Param("active") Boolean active, Pageable pageable);
}
