package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.SupplierInvoice;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;

public interface SupplierInvoiceRepository extends JpaRepository<SupplierInvoice, Long>, JpaSpecificationExecutor<SupplierInvoice> {
    boolean existsByLinesProductId(Long productId);

    @Query("""
            select i from SupplierInvoice i
            join fetch i.supplier
            where i.outstandingAmount > 0
            order by i.dueDate asc nulls last, i.invoiceDate asc, i.id asc
            """)
    List<SupplierInvoice> findOpenPayables(Pageable pageable);

    @Query("select count(i) from SupplierInvoice i where i.outstandingAmount > 0")
    long countOpenPayables();

    @Query("select coalesce(sum(i.outstandingAmount), 0) from SupplierInvoice i where i.outstandingAmount > 0")
    BigDecimal sumOpenPayableOutstanding();

    @Query("select coalesce(sum(i.totalAmount), 0) from SupplierInvoice i where i.outstandingAmount > 0")
    BigDecimal sumOpenPayableTotal();

    @Query("select coalesce(sum(i.outstandingAmount), 0) from SupplierInvoice i where i.outstandingAmount > 0 and i.invoiceDate < :today")
    BigDecimal sumOverdueOpenPayables(LocalDate today);

    @Query("""
            select i.supplier.id, coalesce(sum(i.outstandingAmount), 0)
            from SupplierInvoice i
            where i.outstandingAmount > 0
            group by i.supplier.id
            """)
    List<Object[]> summarizeOpenPayablesBySupplier();

    @Query("""
            select coalesce(sum(i.outstandingAmount), 0)
            from SupplierInvoice i
            where i.supplier.id = :supplierId
              and i.outstandingAmount > 0
            """)
    BigDecimal sumOpenPayablesBySupplierId(Long supplierId);

    @Query("""
            select i from SupplierInvoice i
            join fetch i.supplier
            left join fetch i.store
            where i.invoiceDate >= :from
              and i.invoiceDate <= :to
            order by i.invoiceDate asc, i.id asc
            """)
    List<SupplierInvoice> findReportInvoices(LocalDate from, LocalDate to);

    @Query("""
            select i from SupplierInvoice i
            join fetch i.supplier
            order by i.createdAt desc, i.id desc
            """)
    List<SupplierInvoice> findRecentForLedger(Pageable pageable);

    @Query("""
            select i.status, line.quantity, i.invoiceNumber, i.createdAt
            from SupplierInvoice i
            join i.lines line
            where line.product.id = :productId
            order by i.createdAt desc, i.id desc
            """)
    List<Object[]> findProductHistoryRows(Long productId);
}
