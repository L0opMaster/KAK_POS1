package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.domain.PriceList;
import com.kaknnea.pos.domain.PriceListItem;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.dto.PriceListDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.PriceListRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.StoreRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

@Service
public class PriceListService {
    private final PriceListRepository priceListRepository;
    private final ProductRepository productRepository;
    private final StoreRepository storeRepository;

    public PriceListService(PriceListRepository priceListRepository, ProductRepository productRepository, StoreRepository storeRepository) {
        this.priceListRepository = priceListRepository;
        this.productRepository = productRepository;
        this.storeRepository = storeRepository;
    }

    @Transactional(readOnly = true)
    public List<PriceListDtos.PriceListResponse> list() {
        return priceListRepository.findAll().stream().map(this::toResponse).toList();
    }

    @Transactional
    public PriceListDtos.PriceListResponse create(PriceListDtos.PriceListRequest request) {
        PriceList priceList = new PriceList();
        apply(priceList, request);
        validateNoScopeOverlap(priceList);
        return toResponse(priceListRepository.save(priceList));
    }

    @Transactional
    public PriceListDtos.PriceListResponse update(Long id, PriceListDtos.PriceListRequest request) {
        PriceList priceList = priceListRepository.findById(id).orElseThrow(() -> new ApiException("Price list not found"));
        apply(priceList, request);
        validateNoScopeOverlap(priceList);
        return toResponse(priceListRepository.save(priceList));
    }

    /**
     * Resolve the best price for a product given a customer's type (RETAIL/WHOLESALE/etc.).
     * Returns null if no matching active price list covers this customer group + product.
     */
    @Transactional(readOnly = true)
    public PriceResolution resolvePriceForCustomer(Customer customer, Long productId, Instant now) {
        if (customer == null || customer.getType() == null) return null;
        String customerGroup = customer.getType().trim().toUpperCase();
        List<PriceList> effectiveLists = priceListRepository.findEffectiveLists(now);
        for (PriceList priceList : effectiveLists) {
            if (!customerGroup.equals(normalizeScope(priceList.getCustomerGroup()))) continue;
            for (PriceListItem item : priceList.getItems()) {
                if (item.getProduct().getId().equals(productId)) {
                    return new PriceResolution(item.getPrice(), item.getMinimumOrderQty());
                }
            }
        }
        return null;
    }

    /** Immutable result from resolvePriceForCustomer */
    public record PriceResolution(BigDecimal price, BigDecimal minimumOrderQty) {}

    private void apply(PriceList priceList, PriceListDtos.PriceListRequest request) {
        priceList.setName(request.getName().trim());
        priceList.setCurrencyCode(request.getCurrencyCode().trim().toUpperCase());
        priceList.setCustomerGroup(request.getCustomerGroup());
        priceList.setStartsAt(request.getStartsAt());
        priceList.setEndsAt(request.getEndsAt());
        priceList.setPriority(request.getPriority());
        priceList.setActive(request.isActive());
        Store store = null;
        if (request.getStoreId() != null) {
            store = storeRepository.findById(request.getStoreId()).orElseThrow(() -> new ApiException("Store not found"));
        }
        priceList.setStore(store);
        priceList.getItems().clear();
        if (request.getItems() != null) {
            for (PriceListDtos.PriceListItemRequest itemRequest : request.getItems()) {
                Product product = productRepository.findById(itemRequest.getProductId())
                        .orElseThrow(() -> new ApiException("Product not found"));
                PriceListItem item = new PriceListItem();
                item.setPriceList(priceList);
                item.setProduct(product);
                item.setPrice(itemRequest.getPrice());
                item.setMinimumOrderQty(itemRequest.getMinimumOrderQty());
                priceList.getItems().add(item);
            }
        }
    }

    private void validateNoScopeOverlap(PriceList candidate) {
        var existingLists = priceListRepository.findAll().stream()
                .filter(existing -> existing.getId() == null || !Objects.equals(existing.getId(), candidate.getId()))
                .filter(existing -> sameScope(existing, candidate))
                .sorted(Comparator.comparing(PriceList::getName))
                .toList();
        for (PriceList existing : existingLists) {
            if (overlaps(existing, candidate)) {
                throw new ApiException("Price list date range overlaps with " + existing.getName() + " for the same store/customer scope");
            }
        }
    }

    private boolean sameScope(PriceList left, PriceList right) {
        Long leftStoreId = left.getStore() != null ? left.getStore().getId() : null;
        Long rightStoreId = right.getStore() != null ? right.getStore().getId() : null;
        String leftGroup = normalizeScope(left.getCustomerGroup());
        String rightGroup = normalizeScope(right.getCustomerGroup());
        return Objects.equals(leftStoreId, rightStoreId) && Objects.equals(leftGroup, rightGroup);
    }

    private String normalizeScope(String value) {
        return value == null || value.isBlank() ? null : value.trim().toUpperCase();
    }

    private boolean overlaps(PriceList left, PriceList right) {
        var leftStart = left.getStartsAt();
        var leftEnd = left.getEndsAt();
        var rightStart = right.getStartsAt();
        var rightEnd = right.getEndsAt();
        boolean leftStartsBeforeRightEnds = rightEnd == null || leftStart == null || !leftStart.isAfter(rightEnd);
        boolean rightStartsBeforeLeftEnds = leftEnd == null || rightStart == null || !rightStart.isAfter(leftEnd);
        return leftStartsBeforeRightEnds && rightStartsBeforeLeftEnds;
    }

    public PriceListDtos.PriceListResponse toResponse(PriceList priceList) {
        PriceListDtos.PriceListResponse response = new PriceListDtos.PriceListResponse();
        response.setId(priceList.getId());
        response.setName(priceList.getName());
        response.setCurrencyCode(priceList.getCurrencyCode());
        response.setCustomerGroup(priceList.getCustomerGroup());
        response.setStoreId(priceList.getStore() != null ? priceList.getStore().getId() : null);
        response.setStoreName(priceList.getStore() != null ? priceList.getStore().getName() : null);
        response.setStartsAt(priceList.getStartsAt());
        response.setEndsAt(priceList.getEndsAt());
        response.setPriority(priceList.getPriority());
        response.setActive(priceList.isActive());
        List<PriceListDtos.PriceListItemResponse> items = new ArrayList<>();
        for (PriceListItem item : priceList.getItems()) {
            PriceListDtos.PriceListItemResponse itemResponse = new PriceListDtos.PriceListItemResponse();
            itemResponse.setId(item.getId());
            itemResponse.setProductId(item.getProduct().getId());
            itemResponse.setProductNameEn(item.getProduct().getNameEn());
            itemResponse.setProductNameKm(item.getProduct().getNameKm());
            itemResponse.setPrice(item.getPrice());
            itemResponse.setMinimumOrderQty(item.getMinimumOrderQty());
            items.add(itemResponse);
        }
        response.setItems(items);
        return response;
    }
}
