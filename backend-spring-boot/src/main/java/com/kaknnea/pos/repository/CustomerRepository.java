package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Customer;
import java.util.Optional;
import java.math.BigDecimal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

public interface CustomerRepository extends JpaRepository<Customer, Long> {
    Optional<Customer> findByCustomerCode(String customerCode);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Customer c where c.id = :id")
    Optional<Customer> findByIdForUpdate(@Param("id") Long id);

    @Query("""
            select c from Customer c
            where (:q = '' or
                lower(coalesce(c.customerCode, '')) like lower(concat('%', :q, '%')) or
                lower(coalesce(c.nameEn, '')) like lower(concat('%', :q, '%')) or
                lower(coalesce(c.nameKm, '')) like lower(concat('%', :q, '%')) or
                lower(coalesce(c.displayName, '')) like lower(concat('%', :q, '%')) or
                lower(coalesce(c.phone, '')) like lower(concat('%', :q, '%')) or
                lower(coalesce(c.email, '')) like lower(concat('%', :q, '%')))
              and (:type is null or c.type = :type)
              and (:status is null or c.status = :status)
            order by c.createdAt desc
            """)
    Page<Customer> search(
            @Param("q") String q,
            @Param("type") String type,
            @Param("status") String status,
            Pageable pageable);

    @Query("select coalesce(sum(c.creditLimit), 0) from Customer c")
    BigDecimal sumCreditLimit();
}
