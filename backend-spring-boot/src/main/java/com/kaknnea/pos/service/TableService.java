package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.RestaurantTable;
import com.kaknnea.pos.dto.TableDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.TableRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.SecurityUtil;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// Removed unused imports: com.kaknnea.pos.domain.User, java.time.Instant, java.time.LocalDateTime
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class TableService {
    private final TableRepository tableRepository;
    private final AuditService auditService;
    private final UserRepository userRepository;

    public TableService(TableRepository tableRepository, AuditService auditService, UserRepository userRepository) {
        this.tableRepository = tableRepository;
        this.auditService = auditService;
        this.userRepository = userRepository;
    }

    public TableDtos.TablePageResponse search(TableDtos.TableSearchRequest request) {
        Pageable pageable = PageRequest.of(
                request.getPage() != null ? request.getPage() : 0,
                request.getSize() != null ? request.getSize() : 20,
                Sort.by("tableNumber").ascending());

        Page<RestaurantTable> page;
        if (request.getSearch() != null && !request.getSearch().trim().isEmpty()) {
            // Simple search implementation - you might want to enhance this
            page = tableRepository.findAll(pageable);
        } else if (request.getStatus() != null && !request.getStatus().trim().isEmpty()) {
            page = tableRepository.findByStatus(request.getStatus(), pageable);
        } else if (request.getSection() != null && !request.getSection().trim().isEmpty()) {
            page = tableRepository.findBySection(request.getSection(), pageable);
        } else if (request.getIsActive() != null) {
            if (request.getIsActive()) {
                page = tableRepository.findByIsActiveTrue(pageable);
            } else {
                page = tableRepository.findAll(pageable);
            }
        } else {
            page = tableRepository.findAll(pageable);
        }

        List<TableDtos.TableResponse> content = page.getContent().stream()
                .filter(table -> request.getIsActive() == null || table.getIsActive().equals(request.getIsActive()))
                .filter(table -> request.getSearch() == null || request.getSearch().trim().isEmpty() ||
                        table.getTableNumber().toLowerCase().contains(request.getSearch().toLowerCase()) ||
                        (table.getDisplayName() != null
                                && table.getDisplayName().toLowerCase().contains(request.getSearch().toLowerCase())))
                .map(this::toResponse)
                .collect(Collectors.toList());

        TableDtos.TablePageResponse response = new TableDtos.TablePageResponse();
        response.setContent(content);
        response.setPage(page.getNumber());
        response.setSize(page.getSize());
        response.setTotalElements(page.getTotalElements());
        response.setTotalPages(page.getTotalPages());

        return response;
    }

    public List<TableDtos.TableResponse> listActive() {
        return tableRepository.findAllActive().stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public TableDtos.TableResponse create(TableDtos.TableCreateRequest request) {
        if (tableRepository.findByTableNumber(request.getTableNumber()).isPresent()) {
            throw new ApiException("Table number already exists: " + request.getTableNumber());
        }

        RestaurantTable table = new RestaurantTable();
        table.setTableNumber(request.getTableNumber());
        table.setDisplayName(request.getDisplayName());
        table.setCapacity(request.getCapacity());
        table.setSection(request.getSection());
        table.setNotes(request.getNotes());
        table.setStatus("AVAILABLE");
        table.setIsActive(true);

        RestaurantTable saved = tableRepository.save(table);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "TABLE_CREATE", "RestaurantTable", String.valueOf(saved.getId()), null,
                "Created table: " + saved.getTableNumber());

        return toResponse(saved);
    }

    @Transactional
    public TableDtos.TableResponse update(Long id, TableDtos.TableUpdateRequest request) {
        RestaurantTable table = tableRepository.findById(id)
                .orElseThrow(() -> new ApiException("Table not found"));

        String before = table.toString();

        if (request.getDisplayName() != null)
            table.setDisplayName(request.getDisplayName());
        if (request.getCapacity() != null)
            table.setCapacity(request.getCapacity());
        if (request.getSection() != null)
            table.setSection(request.getSection());
        if (request.getNotes() != null)
            table.setNotes(request.getNotes());
        if (request.getStatus() != null)
            table.setStatus(request.getStatus());
        if (request.getIsActive() != null)
            table.setIsActive(request.getIsActive());

        RestaurantTable saved = tableRepository.save(table);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "TABLE_UPDATE", "RestaurantTable", String.valueOf(saved.getId()), before,
                saved.toString());

        return toResponse(saved);
    }

    @Transactional
    public void delete(Long id) {
        RestaurantTable table = tableRepository.findById(id)
                .orElseThrow(() -> new ApiException("Table not found"));

        // Check if table has active sales
        if (table.getStatus().equals("OCCUPIED")) {
            throw new ApiException("Cannot delete table that is currently occupied");
        }

        String before = table.toString();
        tableRepository.delete(table);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "TABLE_DELETE", "RestaurantTable", String.valueOf(id), before, null);
    }

    public List<TableDtos.TableResponse> bulkUpdateStatus(List<Long> tableIds, String status) {
        List<RestaurantTable> tables = tableRepository.findAllById(tableIds);
        List<TableDtos.TableResponse> responses = new ArrayList<>();

        for (RestaurantTable table : tables) {
            String before = table.getStatus();
            table.setStatus(status);
            table.setUpdatedAt(java.time.Instant.now());
            RestaurantTable saved = tableRepository.save(table);
            responses.add(toResponse(saved));

            var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
            auditService.log(actor, "TABLE_BULK_UPDATE", "RestaurantTable",
                    table.getId().toString(), "status: " + before, "status: " + status);
        }

        return responses;
    }

    public void bulkDelete(List<Long> tableIds) {
        List<RestaurantTable> tables = tableRepository.findAllById(tableIds);
        for (RestaurantTable table : tables) {
            if (table.getStatus().equals("OCCUPIED")) {
                throw new ApiException("Cannot delete table " + table.getTableNumber() + " that is currently occupied");
            }
            var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
            auditService.log(actor, "TABLE_BULK_DELETE", "RestaurantTable",
                    table.getId().toString(), table.toString(), null);
        }
        tableRepository.deleteAllById(tableIds);
    }

    public TableDtos.TableResponse getById(Long id) {
        RestaurantTable table = tableRepository.findById(id)
                .orElseThrow(() -> new ApiException("Table not found"));
        return toResponse(table);
    }

    public TableDtos.TableStatsResponse getStats() {
        long totalTables = tableRepository.count();
        long activeTables = tableRepository.countByIsActive(true);
        long availableTables = tableRepository.countByStatusAndIsActive("AVAILABLE", true);
        long occupiedTables = tableRepository.countByStatusAndIsActive("OCCUPIED", true);
        long reservedTables = tableRepository.countByStatusAndIsActive("RESERVED", true);

        TableDtos.TableStatsResponse stats = new TableDtos.TableStatsResponse();
        stats.setTotalTables(totalTables);
        stats.setActiveTables(activeTables);
        stats.setAvailableTables(availableTables);
        stats.setOccupiedTables(occupiedTables);
        stats.setReservedTables(reservedTables);

        return stats;
    }

    private TableDtos.TableResponse toResponse(RestaurantTable table) {
        TableDtos.TableResponse response = new TableDtos.TableResponse();
        response.setId(table.getId());
        response.setTableNumber(table.getTableNumber());
        response.setDisplayName(table.getDisplayName());
        response.setStatus(table.getStatus());
        response.setCapacity(table.getCapacity());
        response.setSection(table.getSection());
        response.setNotes(table.getNotes());
        response.setIsActive(table.getIsActive());
        response.setCreatedAt(table.getCreatedAt() != null ? table.getCreatedAt().toString() : null);
        response.setUpdatedAt(table.getUpdatedAt() != null ? table.getUpdatedAt().toString() : null);
        return response;
    }
}