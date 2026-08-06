package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.Supplier;
import com.kaknnea.pos.domain.SupplierCatalogItem;
import com.kaknnea.pos.domain.Unit;
import com.kaknnea.pos.dto.SupplierCatalogDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.SupplierCatalogItemRepository;
import com.kaknnea.pos.repository.SupplierRepository;
import com.kaknnea.pos.repository.UnitRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class SupplierCatalogService {
    private final SupplierCatalogItemRepository supplierCatalogItemRepository;
    private final SupplierRepository supplierRepository;
    private final ProductRepository productRepository;
    private final UnitRepository unitRepository;

    public SupplierCatalogService(SupplierCatalogItemRepository supplierCatalogItemRepository, SupplierRepository supplierRepository,
                                  ProductRepository productRepository, UnitRepository unitRepository) {
        this.supplierCatalogItemRepository = supplierCatalogItemRepository;
        this.supplierRepository = supplierRepository;
        this.productRepository = productRepository;
        this.unitRepository = unitRepository;
    }

    @Transactional(readOnly = true)
    public List<SupplierCatalogDtos.SupplierCatalogItemResponse> list(Long supplierId) {
        return supplierCatalogItemRepository.findAllBySupplierIdOrderByCreatedAtDesc(supplierId).stream().map(this::toResponse).toList();
    }

    @Transactional
    public SupplierCatalogDtos.SupplierCatalogItemResponse create(SupplierCatalogDtos.SupplierCatalogItemRequest request) {
        SupplierCatalogItem item = new SupplierCatalogItem();
        apply(item, request);
        return toResponse(supplierCatalogItemRepository.save(item));
    }

    @Transactional
    public SupplierCatalogDtos.SupplierCatalogItemResponse update(Long id, SupplierCatalogDtos.SupplierCatalogItemRequest request) {
        SupplierCatalogItem item = supplierCatalogItemRepository.findById(id).orElseThrow(() -> new ApiException("Supplier catalog item not found"));
        apply(item, request);
        return toResponse(supplierCatalogItemRepository.save(item));
    }

    private void apply(SupplierCatalogItem item, SupplierCatalogDtos.SupplierCatalogItemRequest request) {
        Supplier supplier = supplierRepository.findById(request.getSupplierId()).orElseThrow(() -> new ApiException("Supplier not found"));
        Product product = productRepository.findById(request.getProductId()).orElseThrow(() -> new ApiException("Product not found"));
        Unit purchaseUnit = request.getPurchaseUnitId() == null ? null
                : unitRepository.findById(request.getPurchaseUnitId()).orElseThrow(() -> new ApiException("Unit not found"));
        item.setSupplier(supplier);
        item.setProduct(product);
        item.setSupplierSku(request.getSupplierSku());
        item.setPurchaseUnit(purchaseUnit);
        item.setLastCost(request.getLastCost());
        item.setLeadTimeDays(request.getLeadTimeDays());
        item.setMinimumOrderQuantity(request.getMinimumOrderQuantity());
        item.setPackSize(request.getPackSize());
        item.setActive(request.isActive());
    }

    private SupplierCatalogDtos.SupplierCatalogItemResponse toResponse(SupplierCatalogItem item) {
        SupplierCatalogDtos.SupplierCatalogItemResponse response = new SupplierCatalogDtos.SupplierCatalogItemResponse();
        response.setId(item.getId());
        response.setSupplierId(item.getSupplier().getId());
        response.setSupplierName(item.getSupplier().getName());
        response.setProductId(item.getProduct().getId());
        response.setProductNameEn(item.getProduct().getNameEn());
        response.setProductNameKm(item.getProduct().getNameKm());
        response.setSupplierSku(item.getSupplierSku());
        response.setPurchaseUnitId(item.getPurchaseUnit() != null ? item.getPurchaseUnit().getId() : null);
        response.setPurchaseUnitCode(item.getPurchaseUnit() != null ? item.getPurchaseUnit().getCode() : null);
        response.setLastCost(item.getLastCost());
        response.setLeadTimeDays(item.getLeadTimeDays());
        response.setMinimumOrderQuantity(item.getMinimumOrderQuantity());
        response.setPackSize(item.getPackSize());
        response.setActive(item.isActive());
        return response;
    }
}
