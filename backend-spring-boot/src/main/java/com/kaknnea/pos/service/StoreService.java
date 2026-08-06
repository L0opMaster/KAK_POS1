package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.dto.StoreDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.StoreRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class StoreService {
    private final StoreRepository storeRepository;

    public StoreService(StoreRepository storeRepository) {
        this.storeRepository = storeRepository;
    }

    public List<StoreDtos.StoreResponse> list() {
        return storeRepository.findAll().stream().map(this::toResponse).toList();
    }

    public StoreDtos.StoreResponse create(StoreDtos.StoreRequest request) {
        Store store = new Store();
        apply(store, request);
        return toResponse(storeRepository.save(store));
    }

    public StoreDtos.StoreResponse update(Long id, StoreDtos.StoreRequest request) {
        Store store = storeRepository.findById(id).orElseThrow(() -> new ApiException("Store not found"));
        apply(store, request);
        return toResponse(storeRepository.save(store));
    }

    private void apply(Store store, StoreDtos.StoreRequest request) {
        store.setName(request.getName().trim());
        store.setAddress(request.getAddress() == null ? null : request.getAddress().trim());
        store.setPhone(request.getPhone() == null ? null : request.getPhone().trim());
    }

    private StoreDtos.StoreResponse toResponse(Store store) {
        StoreDtos.StoreResponse response = new StoreDtos.StoreResponse();
        response.setId(store.getId());
        response.setName(store.getName());
        response.setAddress(store.getAddress());
        response.setPhone(store.getPhone());
        return response;
    }
}
