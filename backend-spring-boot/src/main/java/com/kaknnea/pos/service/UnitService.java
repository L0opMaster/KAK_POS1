package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Unit;
import com.kaknnea.pos.dto.UnitDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.SupplierCatalogItemRepository;
import com.kaknnea.pos.repository.UnitRepository;
import java.math.BigDecimal;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UnitService {
    private static final Set<String> ALLOWED_BASE_GROUPS = Set.of("COUNT", "WEIGHT", "VOLUME", "LENGTH");

    private final UnitRepository unitRepository;
    private final ProductRepository productRepository;
    private final SupplierCatalogItemRepository supplierCatalogItemRepository;

    public UnitService(
            UnitRepository unitRepository,
            ProductRepository productRepository,
            SupplierCatalogItemRepository supplierCatalogItemRepository) {
        this.unitRepository = unitRepository;
        this.productRepository = productRepository;
        this.supplierCatalogItemRepository = supplierCatalogItemRepository;
    }

    public Page<UnitDtos.UnitResponse> list(String q, Boolean active, Pageable pageable) {
        return unitRepository.search(q == null ? "" : q.trim(), active, pageable)
                .map(this::toResponse);
    }

    public java.util.List<UnitDtos.UnitResponse> listAll() {
        return unitRepository.findAll().stream().map(this::toResponse).toList();
    }

    public UnitDtos.UnitResponse get(Long id) {
        return toResponse(findUnit(id));
    }

    @Transactional
    public UnitDtos.UnitResponse create(UnitDtos.UnitRequest request) {
        Unit unit = new Unit();
        apply(unit, request);
        return toResponse(unitRepository.save(unit));
    }

    @Transactional
    public UnitDtos.UnitResponse update(Long id, UnitDtos.UnitRequest request) {
        Unit unit = findUnit(id);
        String nextCode = normalizedCode(request.getCode());
        if (isReferenced(unit.getId()) && !unit.getCode().equals(nextCode)) {
            throw new ApiException("Referenced unit codes cannot be changed");
        }
        if (unitRepository.countByBaseUnitId(unit.getId()) > 0 && !request.isBaseUnit()) {
            throw new ApiException("Base units with dependent units cannot be converted to derived units");
        }
        apply(unit, request);
        return toResponse(unitRepository.save(unit));
    }

    @Transactional
    public UnitDtos.UnitResponse updateStatus(Long id, boolean active) {
        Unit unit = findUnit(id);
        if ((isProtected(unit) || unitRepository.countByBaseUnitId(unit.getId()) > 0) && !active) {
            throw new ApiException("System default or referenced units cannot be deactivated");
        }
        unit.setActive(active);
        return toResponse(unitRepository.save(unit));
    }

    private void apply(Unit unit, UnitDtos.UnitRequest request) {
        String code = normalizedCode(request.getCode());
        String baseUnitGroup = normalizedBaseGroup(request.getBaseUnitGroup());
        String nameEn = requiredText(
                request.getNameEn() != null ? request.getNameEn() : request.getName(),
                "English name is required");
        String nameKm = requiredText(request.getNameKm(), "Khmer name is required");
        String symbol = requiredText(request.getSymbol(), "Symbol is required");
        boolean isBaseUnit = request.isBaseUnit();
        BigDecimal conversionFactor = normalizedConversionFactor(request.getConversionFactor());

        if (unit.getId() == null) {
            unitRepository.findByCode(code).ifPresent(existing -> {
                throw new ApiException("Unit code already exists");
            });
        } else if (unitRepository.existsByCodeAndIdNot(code, unit.getId())) {
            throw new ApiException("Unit code already exists");
        }

        Unit baseUnit = null;
        if (isBaseUnit) {
            conversionFactor = BigDecimal.ONE;
        } else {
            if (request.getBaseUnitId() == null) {
                throw new ApiException("Derived units must select a base unit");
            }
            baseUnit = findUnit(request.getBaseUnitId());
            if (unit.getId() != null && unit.getId().equals(baseUnit.getId())) {
                throw new ApiException("A unit cannot reference itself as its base unit");
            }
            if (!baseUnit.isBaseUnit()) {
                throw new ApiException("Derived units must reference a base unit");
            }
            if (!normalizedBaseGroup(baseUnit.getBaseUnitGroup()).equals(baseUnitGroup)) {
                throw new ApiException("Base unit must belong to the same family");
            }
        }

        if (unit.getId() != null && isReferenced(unit.getId()) && structurallyChanged(unit, baseUnitGroup, isBaseUnit, baseUnit, conversionFactor)) {
            throw new ApiException("Referenced units cannot change family, conversion, or base-unit structure");
        }

        unit.setCode(code);
        unit.setName(nameEn);
        unit.setNameEn(nameEn);
        unit.setNameKm(nameKm);
        unit.setSymbol(symbol);
        unit.setBaseUnitGroup(baseUnitGroup);
        unit.setBaseUnit(baseUnit);
        unit.setBaseUnitFlag(isBaseUnit);
        unit.setConversionFactor(conversionFactor);
        unit.setActive(request.isActive());
    }

    private String normalizedCode(String code) {
        return code == null ? "" : code.trim().toUpperCase(Locale.US);
    }

    private String normalizedBaseGroup(String baseUnitGroup) {
        String normalized = baseUnitGroup == null ? "" : baseUnitGroup.trim().toUpperCase(Locale.US);
        if (!ALLOWED_BASE_GROUPS.contains(normalized)) {
            throw new ApiException("Unsupported base unit family");
        }
        return normalized;
    }

    private BigDecimal normalizedConversionFactor(BigDecimal conversionFactor) {
        BigDecimal normalized = conversionFactor == null ? BigDecimal.ONE : conversionFactor.stripTrailingZeros();
        if (normalized.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("Conversion factor must be greater than zero");
        }
        return normalized;
    }

    private String requiredText(String value, String errorMessage) {
        String normalized = value == null ? "" : value.trim();
        if (normalized.isEmpty()) {
            throw new ApiException(errorMessage);
        }
        return normalized;
    }

    private boolean structurallyChanged(Unit current, String nextGroup, boolean nextBaseFlag, Unit nextBaseUnit, BigDecimal nextConversionFactor) {
        Long currentBaseUnitId = current.getBaseUnit() == null ? null : current.getBaseUnit().getId();
        Long nextBaseUnitId = nextBaseUnit == null ? null : nextBaseUnit.getId();
        return !normalizedBaseGroup(current.getBaseUnitGroup()).equals(nextGroup)
                || current.isBaseUnit() != nextBaseFlag
                || !Objects.equals(currentBaseUnitId, nextBaseUnitId)
                || current.getConversionFactor().compareTo(nextConversionFactor) != 0;
    }

    private boolean isProtected(Unit unit) {
        return "EACH".equalsIgnoreCase(unit.getCode()) || isReferenced(unit.getId());
    }

    private boolean isReferenced(Long unitId) {
        return productRepository.countBySaleUnitIdOrPurchaseUnitIdOrStockUnitId(unitId, unitId, unitId) > 0
                || supplierCatalogItemRepository.countByPurchaseUnitId(unitId) > 0;
    }

    private Unit findUnit(Long id) {
        return unitRepository.findById(id)
                .orElseThrow(() -> new ApiException("Unit not found"));
    }

    private UnitDtos.UnitResponse toResponse(Unit unit) {
        long productUsageCount = productRepository.countBySaleUnitIdOrPurchaseUnitIdOrStockUnitId(unit.getId(), unit.getId(), unit.getId());
        long supplierCatalogUsageCount = supplierCatalogItemRepository.countByPurchaseUnitId(unit.getId());
        long derivedUnitCount = unitRepository.countByBaseUnitId(unit.getId());
        UnitDtos.UnitResponse response = new UnitDtos.UnitResponse();
        response.setId(unit.getId());
        response.setCode(unit.getCode());
        response.setName(unit.getName());
        response.setNameEn(unit.getNameEn());
        response.setNameKm(unit.getNameKm());
        response.setSymbol(unit.getSymbol());
        response.setBaseUnitGroup(unit.getBaseUnitGroup());
        response.setBaseUnit(unit.isBaseUnit());
        response.setConversionFactor(unit.getConversionFactor());
        response.setBaseUnitId(unit.getBaseUnit() == null ? null : unit.getBaseUnit().getId());
        response.setBaseUnitCode(unit.getBaseUnit() == null ? null : unit.getBaseUnit().getCode());
        response.setBaseUnitName(unit.getBaseUnit() == null ? null : unit.getBaseUnit().getNameEn());
        response.setBaseUnitNameEn(unit.getBaseUnit() == null ? null : unit.getBaseUnit().getNameEn());
        response.setBaseUnitNameKm(unit.getBaseUnit() == null ? null : unit.getBaseUnit().getNameKm());
        response.setActive(unit.isActive());
        response.setProductUsageCount(productUsageCount);
        response.setSupplierCatalogUsageCount(supplierCatalogUsageCount);
        response.setUsageCount(productUsageCount + supplierCatalogUsageCount);
        response.setDerivedUnitCount(derivedUnitCount);
        return response;
    }
}
