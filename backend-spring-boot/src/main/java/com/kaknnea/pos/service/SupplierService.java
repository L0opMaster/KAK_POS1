package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Supplier;
import com.kaknnea.pos.dto.SupplierDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.PurchaseOrderRepository;
import com.kaknnea.pos.repository.SupplierCatalogItemRepository;
import com.kaknnea.pos.repository.SupplierInvoiceRepository;
import com.kaknnea.pos.repository.SupplierRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class SupplierService {
    private final SupplierRepository supplierRepository;
    private final SupplierCatalogItemRepository supplierCatalogItemRepository;
    private final SupplierInvoiceRepository supplierInvoiceRepository;
    private final PurchaseOrderRepository purchaseOrderRepository;

    public SupplierService(
            SupplierRepository supplierRepository,
            SupplierCatalogItemRepository supplierCatalogItemRepository,
            SupplierInvoiceRepository supplierInvoiceRepository,
            PurchaseOrderRepository purchaseOrderRepository) {
        this.supplierRepository = supplierRepository;
        this.supplierCatalogItemRepository = supplierCatalogItemRepository;
        this.supplierInvoiceRepository = supplierInvoiceRepository;
        this.purchaseOrderRepository = purchaseOrderRepository;
    }

    @Transactional(readOnly = true)
    public List<SupplierDtos.SupplierResponse> list() {
        Map<Long, Long> catalogCounts = catalogCountsBySupplier();
        Map<Long, BigDecimal> openPayables = openPayablesBySupplier();
        Map<Long, Instant> lastPurchaseDates = lastPurchaseDatesBySupplier();
        return supplierRepository.findAll().stream()
                .map(supplier -> toResponse(
                        supplier,
                        catalogCounts.getOrDefault(supplier.getId(), 0L),
                        openPayables.getOrDefault(supplier.getId(), BigDecimal.ZERO),
                        lastPurchaseDates.get(supplier.getId())))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public SupplierDtos.SupplierResponse get(Long id) {
        Supplier supplier = supplierRepository.findById(id).orElseThrow(() -> new ApiException("Supplier not found"));
        return toResponse(
                supplier,
                supplierCatalogItemRepository.countBySupplierId(id),
                supplierInvoiceRepository.sumOpenPayablesBySupplierId(id),
                purchaseOrderRepository.findLatestOrderedAtBySupplierId(id));
    }

    @Transactional
    public SupplierDtos.SupplierResponse create(SupplierDtos.SupplierRequest request) {
        Supplier supplier = new Supplier();
        supplier.setName(request.getName());
        supplier.setContactPerson(request.getContactPerson());
        supplier.setPhone(request.getPhone());
        supplier.setEmail(request.getEmail());
        supplier.setAddress(request.getAddress());
        supplier.setPaymentTerms(request.getPaymentTerms());
        supplier.setLeadTimeDays(request.getLeadTimeDays());
        supplier.setTaxId(request.getTaxId());
        supplier.setDefaultCurrency(request.getDefaultCurrency() == null || request.getDefaultCurrency().isBlank() ? "KHR" : request.getDefaultCurrency().trim().toUpperCase());
        supplier.setActive(request.isActive());
        supplier.setNotes(request.getNotes());
        return toResponse(supplierRepository.save(supplier));
    }

    @Transactional
    public SupplierDtos.SupplierResponse update(Long id, SupplierDtos.SupplierRequest request) {
        Supplier supplier = supplierRepository.findById(id).orElseThrow(() -> new ApiException("Supplier not found"));
        supplier.setName(request.getName());
        supplier.setContactPerson(request.getContactPerson());
        supplier.setPhone(request.getPhone());
        supplier.setEmail(request.getEmail());
        supplier.setAddress(request.getAddress());
        supplier.setPaymentTerms(request.getPaymentTerms());
        supplier.setLeadTimeDays(request.getLeadTimeDays());
        supplier.setTaxId(request.getTaxId());
        supplier.setDefaultCurrency(request.getDefaultCurrency() == null || request.getDefaultCurrency().isBlank() ? "KHR" : request.getDefaultCurrency().trim().toUpperCase());
        supplier.setActive(request.isActive());
        supplier.setNotes(request.getNotes());
        return toResponse(supplierRepository.save(supplier));
    }

    @Transactional
    public void delete(Long id) {
        Supplier supplier = supplierRepository.findById(id).orElseThrow(() -> new ApiException("Supplier not found"));
        supplierCatalogItemRepository.deleteAllBySupplierId(id);
        supplierRepository.delete(supplier);
    }

    private SupplierDtos.SupplierResponse toResponse(Supplier supplier) {
        Long supplierId = supplier.getId();
        return toResponse(
                supplier,
                supplierId == null ? 0L : supplierCatalogItemRepository.countBySupplierId(supplierId),
                supplierId == null ? BigDecimal.ZERO : supplierInvoiceRepository.sumOpenPayablesBySupplierId(supplierId),
                supplierId == null ? null : purchaseOrderRepository.findLatestOrderedAtBySupplierId(supplierId));
    }

    private SupplierDtos.SupplierResponse toResponse(
            Supplier supplier,
            Long catalogItemCount,
            BigDecimal openPayable,
            Instant lastPurchaseDate) {
        SupplierDtos.SupplierResponse resp = new SupplierDtos.SupplierResponse();
        resp.setId(supplier.getId());
        resp.setName(supplier.getName());
        resp.setContactPerson(supplier.getContactPerson());
        resp.setPhone(supplier.getPhone());
        resp.setEmail(supplier.getEmail());
        resp.setAddress(supplier.getAddress());
        resp.setPaymentTerms(supplier.getPaymentTerms());
        resp.setLeadTimeDays(supplier.getLeadTimeDays());
        resp.setTaxId(supplier.getTaxId());
        resp.setDefaultCurrency(supplier.getDefaultCurrency());
        resp.setActive(supplier.isActive());
        resp.setNotes(supplier.getNotes());
        resp.setCatalogItemCount(catalogItemCount == null ? 0L : catalogItemCount);
        resp.setOpenPayable(openPayable == null ? BigDecimal.ZERO : openPayable);
        resp.setLastPurchaseDate(lastPurchaseDate == null ? null : lastPurchaseDate.toString());
        return resp;
    }

    private Map<Long, Long> catalogCountsBySupplier() {
        Map<Long, Long> counts = new HashMap<>();
        supplierCatalogItemRepository.summarizeCountsBySupplier()
                .forEach(row -> counts.put((Long) row[0], ((Number) row[1]).longValue()));
        return counts;
    }

    private Map<Long, BigDecimal> openPayablesBySupplier() {
        Map<Long, BigDecimal> payables = new HashMap<>();
        supplierInvoiceRepository.summarizeOpenPayablesBySupplier()
                .forEach(row -> payables.put((Long) row[0], (BigDecimal) row[1]));
        return payables;
    }

    private Map<Long, Instant> lastPurchaseDatesBySupplier() {
        Map<Long, Instant> dates = new HashMap<>();
        purchaseOrderRepository.summarizeLatestOrderedAtBySupplier()
                .forEach(row -> dates.put((Long) row[0], (Instant) row[1]));
        return dates;
    }
}
