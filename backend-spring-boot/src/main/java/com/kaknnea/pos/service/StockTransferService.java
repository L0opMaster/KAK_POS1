package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.dto.TransferDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class StockTransferService {
    private final StockTransferRepository stockTransferRepository;
    private final StoreRepository storeRepository;
    private final ProductRepository productRepository;
    private final StockItemRepository stockItemRepository;
    private final StockMovementRepository stockMovementRepository;

    public StockTransferService(StockTransferRepository stockTransferRepository,
            StoreRepository storeRepository,
            ProductRepository productRepository,
            StockItemRepository stockItemRepository,
            StockMovementRepository stockMovementRepository) {
        this.stockTransferRepository = stockTransferRepository;
        this.storeRepository = storeRepository;
        this.productRepository = productRepository;
        this.stockItemRepository = stockItemRepository;
        this.stockMovementRepository = stockMovementRepository;
    }

    @Transactional(readOnly = true)
    public List<TransferDtos.TransferResponse> list() {
        return stockTransferRepository.findTop200ByOrderByIdDesc().stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional
    public TransferDtos.TransferResponse create(TransferDtos.TransferCreateRequest request) {
        if (request.getFromStoreId() == null || request.getToStoreId() == null) {
            throw new ApiException("Source and destination store are required");
        }
        if (request.getFromStoreId().equals(request.getToStoreId())) {
            throw new ApiException("Source and destination store must be different");
        }
        if (request.getLines() == null || request.getLines().isEmpty()) {
            throw new ApiException("Add at least one transfer line");
        }
        Store fromStore = storeRepository.findById(request.getFromStoreId())
                .orElseThrow(() -> new ApiException("From store not found"));
        Store toStore = storeRepository.findById(request.getToStoreId())
                .orElseThrow(() -> new ApiException("To store not found"));
        StockTransfer transfer = new StockTransfer();
        transfer.setFromStore(fromStore);
        transfer.setToStore(toStore);
        transfer.setStatus("DRAFT");
        transfer.setNotes(request.getNotes());
        transfer.setLines(request.getLines().stream().map(lineReq -> {
            if (lineReq.getProductId() == null) {
                throw new ApiException("Product is required for each transfer line");
            }
            if (lineReq.getQuantity() == null || lineReq.getQuantity().compareTo(BigDecimal.ZERO) <= 0) {
                throw new ApiException("Transfer quantity must be greater than zero");
            }
            Product product = productRepository.findById(lineReq.getProductId())
                    .orElseThrow(() -> new ApiException("Product not found"));
            if (!product.isTrackInventory()) {
                throw new ApiException(product.getNameEn() + " is not inventory tracked");
            }
            StockTransferLine line = new StockTransferLine();
            line.setTransfer(transfer);
            line.setProduct(product);
            line.setQuantity(lineReq.getQuantity());
            return line;
        }).collect(Collectors.toList()));
        StockTransfer saved = stockTransferRepository.save(transfer);
        // Assign the human-readable transfer number now that we have the DB-generated ID
        if (saved.getTransferNumber() == null) {
            saved.setTransferNumber(
                    String.format("TRF-%d-%04d", java.time.Year.now().getValue(), saved.getId()));
            saved = stockTransferRepository.save(saved);
        }
        return toResponse(saved);
    }

    @Transactional
    public TransferDtos.TransferResponse complete(Long id) {
        StockTransfer transfer = stockTransferRepository.findById(id)
                .orElseThrow(() -> new ApiException("Transfer not found"));
        if (!"DRAFT".equals(transfer.getStatus())) {
            throw new ApiException("Transfer already completed");
        }
        for (StockTransferLine line : transfer.getLines()) {
            StockItem fromStock = stockItemRepository
                    .findByProductIdAndStoreId(line.getProduct().getId(), transfer.getFromStore().getId())
                    .orElseThrow(() -> new ApiException("From store stock missing"));
            StockItem toStock = stockItemRepository
                    .findByProductIdAndStoreId(line.getProduct().getId(), transfer.getToStore().getId())
                    .orElseGet(() -> {
                        StockItem s = new StockItem();
                        s.setProduct(line.getProduct());
                        s.setStore(transfer.getToStore());
                        s.setQuantity(BigDecimal.ZERO);
                        s.setLowStockThreshold(line.getProduct().getLowStockThreshold());
                        return s;
                    });
            BigDecimal newFrom = fromStock.getQuantity().subtract(line.getQuantity());
            if (newFrom.compareTo(BigDecimal.ZERO) < 0) {
                throw new ApiException("Insufficient stock for transfer");
            }
            fromStock.setQuantity(newFrom);
            toStock.setQuantity(toStock.getQuantity().add(line.getQuantity()));
            stockItemRepository.save(fromStock);
            stockItemRepository.save(toStock);

            StockMovement out = new StockMovement();
            out.setProduct(line.getProduct());
            out.setStore(transfer.getFromStore());
            out.setMovementType("TRANSFER_OUT");
            out.setQuantity(line.getQuantity().negate());
            out.setReason(transfer.getNotes() == null || transfer.getNotes().isBlank()
                    ? "Transfer"
                    : transfer.getNotes());
            stockMovementRepository.save(out);

            StockMovement in = new StockMovement();
            in.setProduct(line.getProduct());
            in.setStore(transfer.getToStore());
            in.setMovementType("TRANSFER_IN");
            in.setQuantity(line.getQuantity());
            in.setReason(transfer.getNotes() == null || transfer.getNotes().isBlank()
                    ? "Transfer"
                    : transfer.getNotes());
            stockMovementRepository.save(in);
        }
        transfer.setStatus("COMPLETED");
        transfer.setCompletedAt(Instant.now());
        return toResponse(stockTransferRepository.save(transfer));
    }

    @Transactional
    public TransferDtos.TransferResponse cancel(Long id) {
        StockTransfer transfer = stockTransferRepository.findById(id)
                .orElseThrow(() -> new ApiException("Transfer not found"));
        if (!"DRAFT".equals(transfer.getStatus())) {
            throw new ApiException("Only draft transfers can be cancelled");
        }
        transfer.setStatus("CANCELLED");
        return toResponse(stockTransferRepository.save(transfer));
    }

    private TransferDtos.TransferResponse toResponse(StockTransfer transfer) {
        TransferDtos.TransferResponse resp = new TransferDtos.TransferResponse();
        resp.setId(transfer.getId());
        resp.setTransferNumber(transfer.getTransferNumber());
        resp.setFromStoreId(transfer.getFromStore().getId());
        resp.setFromStoreName(transfer.getFromStore().getName());
        resp.setToStoreId(transfer.getToStore().getId());
        resp.setToStoreName(transfer.getToStore().getName());
        resp.setStatus(transfer.getStatus());
        resp.setNotes(transfer.getNotes());
        resp.setCreatedAt(transfer.getCreatedAt());
        resp.setCompletedAt(transfer.getCompletedAt());
        resp.setLines(transfer.getLines().stream().map(line -> {
            TransferDtos.TransferLineResponse lr = new TransferDtos.TransferLineResponse();
            lr.setProductId(line.getProduct().getId());
            lr.setProductNameEn(line.getProduct().getNameEn());
            lr.setStockUnitCode(
                    line.getProduct().getStockUnit() != null ? line.getProduct().getStockUnit().getCode() : "EACH");
            lr.setQuantity(line.getQuantity());
            return lr;
        }).collect(Collectors.toList()));
        return resp;
    }
}
