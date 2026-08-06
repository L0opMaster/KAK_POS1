package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Sale;
import java.util.List;
import java.util.Optional;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Collection;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

public interface SaleRepository extends JpaRepository<Sale, Long> {
  interface ReservedProductQuantityView {
    Long getProductId();
    BigDecimal getReservedQty();
  }

  List<Sale> findByCustomerId(Long customerId);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select s from Sale s where s.id = :id")
  Optional<Sale> findByIdForUpdate(@Param("id") Long id);

  @Query("SELECT s FROM Sale s WHERE s.customer.id = :customerId AND s.status = :status ORDER BY s.creditDueAt ASC NULLS LAST, s.createdAt ASC")
  List<Sale> findByCustomerIdAndStatusOrderByCreditDueAtAscCreatedAtAsc(@Param("customerId") Long customerId,
      @Param("status") String status);

  Optional<Sale> findByClientRef(String clientRef);

  List<Sale> findByStatusOrderByCreatedAtDesc(String status);

  List<Sale> findByShiftIdAndStatus(Long shiftId, String status);

  List<Sale> findByShiftIdAndStatusOrderByCreatedAtDesc(Long shiftId, String status);

  List<Sale> findByShiftIdOrderByCreatedAtDesc(Long shiftId);

  @Query("select count(s.id) from Sale s where s.shift.id = :shiftId and s.status = 'HOLD'")
  long countHeldTicketsByShift(@Param("shiftId") Long shiftId);

  @Query("select count(s.id) from Sale s where s.shift.id = :shiftId and s.status in ('DRAFT','IN_PROGRESS')")
  long countInProgressTicketsByShift(@Param("shiftId") Long shiftId);

  @Query("""
      select s from Sale s
      left join fetch s.customer
      where s.shift.id = :shiftId
        and s.status in ('DRAFT','IN_PROGRESS')
      order by s.createdAt desc, s.id desc
      """)
  List<Sale> findInProgressTicketsByShift(@Param("shiftId") Long shiftId);

  @Query("""
      select s from Sale s
      left join fetch s.customer
      where s.shift.id = :shiftId
        and s.status = 'HOLD'
      order by s.createdAt desc, s.id desc
      """)
  List<Sale> findHeldTicketsByShift(@Param("shiftId") Long shiftId);

  @Query("select coalesce(sum(s.grandTotal - s.paidAmount), 0) from Sale s where s.shift.id = :shiftId and s.status = 'CREDIT'")
  BigDecimal outstandingCreditByShift(@Param("shiftId") Long shiftId);

  List<Sale> findAllByOrderByCreatedAtDesc();

  @Query("select s from Sale s where s.status like 'ESTIMATE%' order by s.createdAt desc")
  List<Sale> findEstimates();

  @Query("select s from Sale s where s.status like 'ESTIMATE%' and s.status = :status order by s.createdAt desc")
  List<Sale> findEstimatesByStatus(@Param("status") String status);

  long countByStatusIn(Collection<String> statuses);

  @Query("""
      select s from Sale s
      left join fetch s.customer
      where upper(s.status) = 'CREDIT'
        and coalesce(s.grandTotal, 0) > coalesce(s.paidAmount, 0)
      order by s.creditDueAt asc nulls last, s.createdAt asc, s.id asc
      """)
  List<Sale> findOpenReceivables(Pageable pageable);

  @Query("""
      select count(s) from Sale s
      where upper(s.status) = 'CREDIT'
        and coalesce(s.grandTotal, 0) > coalesce(s.paidAmount, 0)
      """)
  long countOpenReceivables();

  @Query("""
      select coalesce(sum(coalesce(s.grandTotal, 0) - coalesce(s.paidAmount, 0)), 0)
      from Sale s
      where upper(s.status) = 'CREDIT'
        and coalesce(s.grandTotal, 0) > coalesce(s.paidAmount, 0)
      """)
  BigDecimal sumOpenReceivableOutstanding();

  @Query("""
      select coalesce(sum(coalesce(s.grandTotal, 0) - coalesce(s.paidAmount, 0)), 0)
      from Sale s
      where upper(s.status) = 'CREDIT'
        and coalesce(s.grandTotal, 0) > coalesce(s.paidAmount, 0)
        and s.createdAt < :cutoff
      """)
  BigDecimal sumOpenReceivableOutstandingBefore(@Param("cutoff") Instant cutoff);

  @Query("""
      select distinct s from Sale s
      left join fetch s.customer
      left join fetch s.payments
      where upper(s.status) = 'CREDIT'
        and coalesce(s.grandTotal, 0) > coalesce(s.paidAmount, 0)
      order by s.createdAt asc, s.id asc
      """)
  List<Sale> findOutstandingReportSales();

  @Query("""
      select s from Sale s
      where (:shiftId is null or s.shift.id = :shiftId)
        and (:status is null or s.status = :status)
        and (:dateFrom is null or s.createdAt >= :dateFrom)
        and (:dateTo is null or s.createdAt < :dateTo)
      order by s.createdAt desc
      """)
  List<Sale> findFiltered(
      @Param("shiftId") Long shiftId,
      @Param("status") String status,
      @Param("dateFrom") Instant dateFrom,
      @Param("dateTo") Instant dateTo);

  @Query("""
      select s from Sale s
      where s.createdAt >= :dateFrom
        and s.createdAt < :dateTo
        and s.status in :statuses
      order by s.createdAt asc, s.id asc
      """)
  List<Sale> findReportSalesByCreatedAt(
      @Param("dateFrom") Instant dateFrom,
      @Param("dateTo") Instant dateTo,
      @Param("statuses") Collection<String> statuses);

  @Query("""
      select s from Sale s
      where s.status in :statuses
        and (
          (s.orderDate is not null and s.orderDate >= :fromDate and s.orderDate <= :toDate)
          or (s.orderDate is null and s.createdAt >= :createdFrom and s.createdAt < :createdTo)
        )
      order by s.createdAt asc, s.id asc
      """)
  List<Sale> findReportSalesByInvoiceDate(
      @Param("fromDate") LocalDate fromDate,
      @Param("toDate") LocalDate toDate,
      @Param("createdFrom") Instant createdFrom,
      @Param("createdTo") Instant createdTo,
      @Param("statuses") Collection<String> statuses);

  @Query("select sum(s.totalAmount) as total, count(s.id) as count from Sale s where s.shift.id = :shiftId and s.status in ('PAID','CREDIT')")
  ShiftSalesView salesByShift(@Param("shiftId") Long shiftId);

  @Query("select coalesce(sum(s.grandTotal), 0) from Sale s where s.customer.id = :customerId and s.status not in ('VOID')")
  BigDecimal totalSalesByCustomerId(@Param("customerId") Long customerId);

  @Query("select max(s.createdAt) from Sale s where s.customer.id = :customerId and s.status not in ('VOID')")
  Instant latestPurchaseDateByCustomerId(@Param("customerId") Long customerId);

  boolean existsByCustomerIdAndStatusAndCreditDueAtBefore(Long customerId, String status, Instant creditDueAt);

  @Query("""
      select s from Sale s
      where (:shiftId is null or s.shift.id = :shiftId)
        and s.status in ('HOLD','IN_PROGRESS','DRAFT')
      order by s.createdAt desc
      """)
  List<Sale> findOpenTickets(@Param("shiftId") Long shiftId);

  @Query("""
      select count(s) from Sale s
      where s.predefinedTicket.id = :predefinedTicketId
        and s.status in ('HOLD','IN_PROGRESS','DRAFT')
      """)
  long countActiveByPredefinedTicketId(@Param("predefinedTicketId") Long predefinedTicketId);

  @Query("""
      select count(s) from Sale s
      where s.predefinedTicket.id = :predefinedTicketId
        and (:excludeSaleId is null or s.id <> :excludeSaleId)
        and s.status in ('HOLD','IN_PROGRESS','DRAFT')
      """)
  long countActiveByPredefinedTicketIdExcluding(@Param("predefinedTicketId") Long predefinedTicketId,
      @Param("excludeSaleId") Long excludeSaleId);

  @Query("""
      select count(s) from Sale s
      where s.table.id = :tableId
        and (:excludeSaleId is null or s.id <> :excludeSaleId)
        and s.status in ('HOLD','IN_PROGRESS','DRAFT')
      """)
  long countActiveByTableIdExcluding(@Param("tableId") Long tableId,
      @Param("excludeSaleId") Long excludeSaleId);

  @Query("""
      select s from Sale s
      where s.status = 'HOLD'
        and s.customer is not null
        and s.paymentTerms is not null
        and s.orderDate is not null
        and s.grandTotal > 0
        and (s.saleNumber is null or s.saleNumber not like 'TICKET-%')
      order by s.createdAt asc
      """)
  List<Sale> findLegacyConfirmedHolds();

  @Query("""
      select sl.product.id as productId, coalesce(sum(sl.quantity - coalesce(sl.refundedQuantity, 0)), 0) as reservedQty
      from SaleLine sl
      join sl.sale s
      join s.shift sh
      where sl.product.id in :productIds
        and s.stockApplied = false
        and s.status in ('DRAFT', 'HOLD', 'IN_PROGRESS')
        and (:storeId is null or sh.store.id = :storeId)
      group by sl.product.id
      """)
  List<ReservedProductQuantityView> findReservedQuantitiesByProductIds(
      @Param("productIds") List<Long> productIds,
      @Param("storeId") Long storeId);
}
