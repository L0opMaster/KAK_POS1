package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.SupplierPayment;
import java.time.Instant;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface SupplierPaymentRepository extends JpaRepository<SupplierPayment, Long>, JpaSpecificationExecutor<SupplierPayment> {
    List<SupplierPayment> findAllBySupplierInvoiceIdOrderByPaidAtDesc(Long supplierInvoiceId);

    boolean existsBySupplierInvoiceId(Long supplierInvoiceId);

    @Query("""
            select p from SupplierPayment p
            join fetch p.supplierInvoice i
            join fetch i.supplier
            order by p.paidAt desc, p.id desc
            """)
    List<SupplierPayment> findRecentForLedger(Pageable pageable);

    @Query("""
            select p from SupplierPayment p
            join fetch p.supplierInvoice i
            join fetch i.supplier
            left join fetch i.store
            where p.paidAt >= :start
              and p.paidAt < :end
              and (p.status is null or p.status = '' or upper(p.status) = 'POSTED')
            order by p.paidAt desc, p.id desc
            """)
    List<SupplierPayment> findReportPayments(Instant start, Instant end);
}
