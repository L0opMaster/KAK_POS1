package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.ProductUnitConversion;
import com.kaknnea.pos.domain.StockItem;
import com.kaknnea.pos.domain.StockMovement;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.domain.Unit;
import com.kaknnea.pos.dto.ProductConversionDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.ProductUnitConversionRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import com.kaknnea.pos.repository.StockMovementRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.UnitRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class ProductConversionService {
    private final ProductUnitConversionRepository conversionRepository;
    private final ProductRepository productRepository;
    private final UnitRepository unitRepository;
    private final StockItemRepository stockItemRepository;
    private final StockMovementRepository stockMovementRepository;
    private final StoreRepository storeRepository;

    public ProductConversionService(ProductUnitConversionRepository conversionRepository,
                                    ProductRepository productRepository,
                                    UnitRepository unitRepository,
                                    StockItemRepository stockItemRepository,
                                    StockMovementRepository stockMovementRepository,
                                    StoreRepository storeRepository) {
        this.conversionRepository = conversionRepository;
        this.productRepository = productRepository;
        this.unitRepository = unitRepository;
        this.stockItemRepository = stockItemRepository;
        this.stockMovementRepository = stockMovementRepository;
        this.storeRepository = storeRepository;
    }

    @Transactional(readOnly = true)
    public List<ProductConversionDtos.ConversionResponse> listForProduct(Long productId) {
        return conversionRepository.findBySourceProductIdOrTargetProductId(productId, productId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public ProductConversionDtos.ConversionResponse create(ProductConversionDtos.ConversionRequest request) {
        Product sourceProduct = productRepository.findById(request.getSourceProductId())
                .orElseThrow(() -> new ApiException("Source product not found"));
        Product targetProduct = productRepository.findById(request.getTargetProductId())
                .orElseThrow(() -> new ApiException("Target product not found"));
        Unit sourceUnit = unitRepository.findById(request.getSourceUnitId())
                .orElseThrow(() -> new ApiException("Source unit not found"));
        Unit targetUnit = unitRepository.findById(request.getTargetUnitId())
                .orElseThrow(() -> new ApiException("Target unit not found"));
        validateConversion(request.getRatio(), sourceProduct, targetProduct, sourceUnit, targetUnit);
        String conversionType = request.getConversionType().trim().toUpperCase();
        if (conversionRepository.existsBySourceProductIdAndTargetProductIdAndSourceUnitIdAndTargetUnitIdAndConversionType(
                sourceProduct.getId(), targetProduct.getId(), sourceUnit.getId(), targetUnit.getId(), conversionType)) {
            throw new ApiException("A conversion rule already exists for this source, target, units, and type");
        }

        ProductUnitConversion conversion = new ProductUnitConversion();
        conversion.setSourceProduct(sourceProduct);
        conversion.setTargetProduct(targetProduct);
        conversion.setSourceUnit(sourceUnit);
        conversion.setTargetUnit(targetUnit);
        conversion.setRatio(request.getRatio());
        conversion.setConversionType(conversionType);
        conversion.setActive(request.isActive());
        return toResponse(conversionRepository.save(conversion));
    }

    @Transactional
    public ProductConversionDtos.ConversionResponse update(Long id, ProductConversionDtos.ConversionRequest request) {
        ProductUnitConversion conversion = conversionRepository.findById(id)
                .orElseThrow(() -> new ApiException("Conversion not found"));
        Product sourceProduct = productRepository.findById(request.getSourceProductId())
                .orElseThrow(() -> new ApiException("Source product not found"));
        Product targetProduct = productRepository.findById(request.getTargetProductId())
                .orElseThrow(() -> new ApiException("Target product not found"));
        Unit sourceUnit = unitRepository.findById(request.getSourceUnitId())
                .orElseThrow(() -> new ApiException("Source unit not found"));
        Unit targetUnit = unitRepository.findById(request.getTargetUnitId())
                .orElseThrow(() -> new ApiException("Target unit not found"));
        validateConversion(request.getRatio(), sourceProduct, targetProduct, sourceUnit, targetUnit);
        String conversionType = request.getConversionType().trim().toUpperCase();
        boolean duplicateExists = conversionRepository
                .findBySourceProductIdOrTargetProductId(sourceProduct.getId(), targetProduct.getId()).stream()
                .anyMatch(existing -> !existing.getId().equals(conversion.getId())
                        && existing.getSourceProduct().getId().equals(sourceProduct.getId())
                        && existing.getTargetProduct().getId().equals(targetProduct.getId())
                        && existing.getSourceUnit().getId().equals(sourceUnit.getId())
                        && existing.getTargetUnit().getId().equals(targetUnit.getId())
                        && existing.getConversionType().equals(conversionType));
        if (duplicateExists) {
            throw new ApiException("A conversion rule already exists for this source, target, units, and type");
        }

        conversion.setSourceProduct(sourceProduct);
        conversion.setTargetProduct(targetProduct);
        conversion.setSourceUnit(sourceUnit);
        conversion.setTargetUnit(targetUnit);
        conversion.setRatio(request.getRatio());
        conversion.setConversionType(conversionType);
        conversion.setActive(request.isActive());
        return toResponse(conversionRepository.save(conversion));
    }

    @Transactional
    public void execute(ProductConversionDtos.ConversionExecuteRequest request) {
        ProductUnitConversion conversion = conversionRepository.findById(request.getConversionId())
                .orElseThrow(() -> new ApiException("Conversion not found"));
        if (!conversion.isActive()) {
            throw new ApiException("Conversion is inactive");
        }
        if (request.getSourceQuantity().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("Conversion quantity must be greater than zero");
        }
        Store store = resolveStore(request.getStoreId());
        StockItem sourceStock = stockItemRepository
                .findByProductIdAndStoreId(conversion.getSourceProduct().getId(), store.getId())
                .orElseThrow(() -> new ApiException("Source stock not found"));
        if (sourceStock.getQuantity().compareTo(request.getSourceQuantity()) < 0) {
            throw new ApiException("Insufficient source stock");
        }
        StockItem targetStock = stockItemRepository
                .findByProductIdAndStoreId(conversion.getTargetProduct().getId(), store.getId())
                .orElseGet(() -> createStockItem(conversion.getTargetProduct(), store));

        BigDecimal targetQuantity = request.getSourceQuantity().multiply(conversion.getRatio());
        sourceStock.setQuantity(sourceStock.getQuantity().subtract(request.getSourceQuantity()));
        targetStock.setQuantity(targetStock.getQuantity().add(targetQuantity));
        stockItemRepository.save(sourceStock);
        stockItemRepository.save(targetStock);

        stockMovementRepository.save(buildMovement(conversion.getSourceProduct(), store, "CONVERSION_OUT",
                request.getSourceQuantity().negate(), request.getReason()));
        stockMovementRepository.save(buildMovement(conversion.getTargetProduct(), store, "CONVERSION_IN",
                targetQuantity, request.getReason()));
    }

    private StockItem createStockItem(Product product, Store store) {
        StockItem stockItem = new StockItem();
        stockItem.setProduct(product);
        stockItem.setStore(store);
        stockItem.setQuantity(BigDecimal.ZERO);
        stockItem.setLowStockThreshold(product.getLowStockThreshold());
        return stockItem;
    }

    private StockMovement buildMovement(Product product, Store store, String type, BigDecimal quantity, String reason) {
        StockMovement movement = new StockMovement();
        movement.setProduct(product);
        movement.setStore(store);
        movement.setMovementType(type);
        movement.setQuantity(quantity);
        movement.setReason(reason == null || reason.isBlank() ? "Conversion" : reason.trim());
        return movement;
    }

    private void validateConversion(BigDecimal ratio, Product sourceProduct, Product targetProduct, Unit sourceUnit, Unit targetUnit) {
        if (ratio == null || ratio.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("Conversion ratio must be greater than zero");
        }
        if (sourceProduct.getId().equals(targetProduct.getId())) {
            throw new ApiException("Source and target products must differ");
        }
        if (!matchesConfiguredUnit(sourceProduct, sourceUnit)) {
            throw new ApiException("Source unit is not configured on the source product");
        }
        if (!matchesConfiguredUnit(targetProduct, targetUnit)) {
            throw new ApiException("Target unit is not configured on the target product");
        }
    }

    private boolean matchesConfiguredUnit(Product product, Unit unit) {
        return (product.getSaleUnit() != null && product.getSaleUnit().getId().equals(unit.getId()))
                || (product.getPurchaseUnit() != null && product.getPurchaseUnit().getId().equals(unit.getId()))
                || (product.getStockUnit() != null && product.getStockUnit().getId().equals(unit.getId()));
    }

    private Store resolveStore(Long storeId) {
        Long resolvedStoreId = storeId != null ? storeId : 1L;
        return storeRepository.findById(resolvedStoreId)
                .orElseThrow(() -> new ApiException("Store not found"));
    }

    private ProductConversionDtos.ConversionResponse toResponse(ProductUnitConversion conversion) {
        ProductConversionDtos.ConversionResponse response = new ProductConversionDtos.ConversionResponse();
        response.setId(conversion.getId());
        response.setSourceProductId(conversion.getSourceProduct().getId());
        response.setSourceProductNameEn(conversion.getSourceProduct().getNameEn());
        response.setTargetProductId(conversion.getTargetProduct().getId());
        response.setTargetProductNameEn(conversion.getTargetProduct().getNameEn());
        response.setSourceUnitId(conversion.getSourceUnit().getId());
        response.setSourceUnitCode(conversion.getSourceUnit().getCode());
        response.setTargetUnitId(conversion.getTargetUnit().getId());
        response.setTargetUnitCode(conversion.getTargetUnit().getCode());
        response.setRatio(conversion.getRatio());
        response.setConversionType(conversion.getConversionType());
        response.setActive(conversion.isActive());
        return response;
    }
}
