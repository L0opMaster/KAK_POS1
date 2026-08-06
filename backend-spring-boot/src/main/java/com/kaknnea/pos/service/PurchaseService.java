package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.dto.PurchaseDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class PurchaseService {
    private final PurchaseRepository purchaseRepository;
    private final SupplierRepository supplierRepository;
    private final ProductRepository productRepository;
    private final StockItemRepository stockItemRepository;
    private final StockMovementRepository stockMovementRepository;
    private final StoreRepository storeRepository;

    public PurchaseService(PurchaseRepository purchaseRepository,
                           SupplierRepository supplierRepository,
                           ProductRepository productRepository,
                           StockItemRepository stockItemRepository,
                           StockMovementRepository stockMovementRepository,
                           StoreRepository storeRepository) {
        this.purchaseRepository = purchaseRepository;
        this.supplierRepository = supplierRepository;
        this.productRepository = productRepository;
        this.stockItemRepository = stockItemRepository;
        this.stockMovementRepository = stockMovementRepository;
        this.storeRepository = storeRepository;
    }

    @Transactional(readOnly = true)
    public List<PurchaseDtos.PurchaseResponse> list() {
        return purchaseRepository.findAll().stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional
    public PurchaseDtos.PurchaseResponse create(PurchaseDtos.PurchaseCreateRequest request) {
        Supplier supplier = supplierRepository.findById(request.getSupplierId())
                .orElseThrow(() -> new ApiException("Supplier not found"));
        Purchase purchase = new Purchase();
        purchase.setSupplier(supplier);
        purchase.setStatus("APPROVED");
        purchase.setPaidAmount(BigDecimal.ZERO);
        // Persist the destination store so receive() uses the correct store
        if (request.getStoreId() != null) {
            Store store = storeRepository.findById(request.getStoreId())
                    .orElseThrow(() -> new ApiException("Store not found"));
            purchase.setStore(store);
        }

        List<PurchaseLine> lines = request.getLines().stream().map(lineReq -> {
            Product product = productRepository.findById(lineReq.getProductId())
                    .orElseThrow(() -> new ApiException("Product not found"));
            if (!product.isPurchasable()) {
                throw new ApiException(product.getNameEn() + " is not marked as purchasable");
            }
            if (!product.isTrackInventory()) {
                throw new ApiException(product.getNameEn() + " is not inventory tracked");
            }
            PurchaseLine line = new PurchaseLine();
            line.setPurchase(purchase);
            line.setProduct(product);
            line.setQuantity(lineReq.getQuantity());
            line.setUnitCost(lineReq.getUnitCost());
            line.setLineTotal(lineReq.getUnitCost().multiply(lineReq.getQuantity()));
            return line;
        }).collect(Collectors.toList());
        purchase.setLines(lines);

        BigDecimal subtotal = lines.stream().map(PurchaseLine::getLineTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal tax = subtotal.multiply(BigDecimal.valueOf(request.getTaxRate())).setScale(2, RoundingMode.HALF_UP);
        BigDecimal total = subtotal.add(tax);
        purchase.setSubtotal(subtotal);
        purchase.setTaxAmount(tax);
        purchase.setTotalAmount(total);

        return toResponse(purchaseRepository.save(purchase));
    }

    @Transactional
    public PurchaseDtos.PurchaseResponse receive(Long id) {
        Purchase purchase = purchaseRepository.findById(id).orElseThrow(() -> new ApiException("Purchase not found"));
        if (!List.of("DRAFT", "APPROVED").contains(purchase.getStatus())) {
            throw new ApiException("Purchase already received");
        }
        // Resolve the destination store: use the stored reference, fall back to store 1 for legacy records
        Store receiveStore = purchase.getStore() != null
                ? purchase.getStore()
                : storeRepository.findById(1L).orElseThrow(() -> new ApiException("No store configured"));

        for (PurchaseLine line : purchase.getLines()) {
            StockItem stock = stockItemRepository.findByProductIdAndStoreId(line.getProduct().getId(), receiveStore.getId())
                    .orElseGet(() -> {
                        StockItem s = new StockItem();
                        s.setProduct(line.getProduct());
                        s.setStore(receiveStore);
                        s.setQuantity(BigDecimal.ZERO);
                        s.setLowStockThreshold(line.getProduct().getLowStockThreshold());
                        return s;
                    });
            BigDecimal oldQty = stock.getQuantity();
            BigDecimal newQty = oldQty.add(line.getQuantity());
            stock.setQuantity(newQty);
            stockItemRepository.save(stock);

            // Weighted-average costing; guard against null cost on new products
            Product product = line.getProduct();
            BigDecimal oldCost = product.getCost() != null ? product.getCost() : BigDecimal.ZERO;
            if (newQty.compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal newCost = oldCost.multiply(oldQty).add(line.getUnitCost().multiply(line.getQuantity()))
                        .divide(newQty, 2, RoundingMode.HALF_UP);
                product.setCost(newCost);
                productRepository.save(product);
            }

            StockMovement movement = new StockMovement();
            movement.setProduct(line.getProduct());
            movement.setStore(receiveStore);
            movement.setMovementType("STOCK_IN");
            movement.setQuantity(line.getQuantity());
            movement.setReason("Purchase #" + purchase.getId());
            stockMovementRepository.save(movement);
        }
        purchase.setStatus("RECEIVED");
        return toResponse(purchaseRepository.save(purchase));
    }

    @Transactional
    public PurchaseDtos.PurchaseResponse pay(Long id, PurchaseDtos.PurchasePayRequest request) {
        Purchase purchase = purchaseRepository.findById(id).orElseThrow(() -> new ApiException("Purchase not found"));
        purchase.setPaidAmount(purchase.getPaidAmount().add(request.getAmount()));
        if (purchase.getPaidAmount().compareTo(purchase.getTotalAmount()) >= 0) {
            purchase.setStatus("PAID");
        }
        return toResponse(purchaseRepository.save(purchase));
    }

    private PurchaseDtos.PurchaseResponse toResponse(Purchase purchase) {
        PurchaseDtos.PurchaseResponse resp = new PurchaseDtos.PurchaseResponse();
        resp.setId(purchase.getId());
        resp.setSupplierId(purchase.getSupplier().getId());
        resp.setStatus(purchase.getStatus());
        resp.setSubtotal(purchase.getSubtotal());
        resp.setTaxAmount(purchase.getTaxAmount());
        resp.setTotalAmount(purchase.getTotalAmount());
        resp.setPaidAmount(purchase.getPaidAmount());
        resp.setLines(purchase.getLines().stream().map(line -> {
            PurchaseDtos.PurchaseLineResponse lr = new PurchaseDtos.PurchaseLineResponse();
            lr.setProductId(line.getProduct().getId());
            lr.setProductNameEn(line.getProduct().getNameEn());
            lr.setProductNameKm(line.getProduct().getNameKm());
            lr.setPurchaseUnitCode(line.getProduct().getPurchaseUnit() != null ? line.getProduct().getPurchaseUnit().getCode() : "EACH");
            lr.setQuantity(line.getQuantity());
            lr.setUnitCost(line.getUnitCost());
            lr.setLineTotal(line.getLineTotal());
            return lr;
        }).collect(Collectors.toList()));
        return resp;
    }
}
