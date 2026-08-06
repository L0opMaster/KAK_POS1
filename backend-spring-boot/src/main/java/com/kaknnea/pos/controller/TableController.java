package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.TableDtos;
import com.kaknnea.pos.service.TableService;
import jakarta.validation.Valid;
import lombok.Data;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/tables")
public class TableController {
    private final TableService tableService;

    public TableController(TableService tableService) {
        this.tableService = tableService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_POS_SALE')")
    public TableDtos.TablePageResponse search(TableDtos.TableSearchRequest request) {
        return tableService.search(request);
    }

    @GetMapping("/active")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_POS_SALE')")
    public List<TableDtos.TableResponse> listActive() {
        return tableService.listActive();
    }

    @GetMapping("/stats")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_POS_SALE')")
    public TableDtos.TableStatsResponse getStats() {
        return tableService.getStats();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public TableDtos.TableResponse getById(@PathVariable Long id) {
        return tableService.getById(id);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public TableDtos.TableResponse create(@Valid @RequestBody TableDtos.TableCreateRequest request) {
        return tableService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public TableDtos.TableResponse update(@PathVariable Long id,
            @Valid @RequestBody TableDtos.TableUpdateRequest request) {
        return tableService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public void delete(@PathVariable Long id) {
        tableService.delete(id);
    }

    @PutMapping("/bulk/status")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public List<TableDtos.TableResponse> bulkUpdateStatus(@RequestBody BulkStatusUpdateRequest request) {
        return tableService.bulkUpdateStatus(request.getTableIds(), request.getStatus());
    }

    @PostMapping("/bulk/delete")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public void bulkDelete(@RequestBody BulkDeleteRequest request) {
        tableService.bulkDelete(request.getTableIds());
    }

    @Data
    public static class BulkStatusUpdateRequest {
        private List<Long> tableIds;
        private String status;
    }

    @Data
    public static class BulkDeleteRequest {
        private List<Long> tableIds;
    }
}