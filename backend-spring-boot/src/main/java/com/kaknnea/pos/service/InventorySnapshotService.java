package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.InventorySnapshot;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.InventorySnapshotRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.StockItemRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Service
public class InventorySnapshotService {
    private final InventorySnapshotRepository inventorySnapshotRepository;
    private final StockItemRepository stockItemRepository;
    private final StoreRepository storeRepository;

    public InventorySnapshotService(
            InventorySnapshotRepository inventorySnapshotRepository,
            StockItemRepository stockItemRepository,
            StoreRepository storeRepository
    ) {
        this.inventorySnapshotRepository = inventorySnapshotRepository;
        this.stockItemRepository = stockItemRepository;
        this.storeRepository = storeRepository;
    }

    @Transactional
    public void snapshot(LocalDate date, Long storeId) {
        Store store = storeRepository.findById(storeId).orElseThrow(() -> new ApiException("Store not found"));
        if (inventorySnapshotRepository.existsBySnapshotDateAndStoreId(date, storeId)) {
            throw new ApiException("Inventory snapshot already exists for this store and date");
        }
        stockItemRepository.findAllByStoreId(storeId).forEach(item -> {
            InventorySnapshot snap = new InventorySnapshot();
            snap.setSnapshotDate(date);
            snap.setProduct(item.getProduct());
            snap.setStore(store);
            snap.setQuantity(item.getQuantity());
            snap.setCountStatus("SNAPSHOT");
            inventorySnapshotRepository.save(snap);
        });
    }
}
