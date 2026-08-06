package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.HeldTicketDtos;
import com.kaknnea.pos.service.HeldTicketService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping({"/api/pos/open-tickets", "/api/pos/held-tickets"})
@PreAuthorize("hasAnyRole('CASHIER','MANAGER','OWNER')")
public class HeldTicketController {
    private final HeldTicketService heldTicketService;

    public HeldTicketController(HeldTicketService heldTicketService) {
        this.heldTicketService = heldTicketService;
    }

    @GetMapping
    public List<HeldTicketDtos.HeldTicketResponse> list(
            @RequestParam(required = false) String storeId,
            @RequestParam(required = false) String terminalId,
            @RequestParam(required = false) Long shiftId) {
        return heldTicketService.list(storeId, terminalId, shiftId);
    }

    @GetMapping("/{id}")
    public HeldTicketDtos.HeldTicketResponse getById(@PathVariable Long id) {
        return heldTicketService.getById(id);
    }

    @PostMapping
    public HeldTicketDtos.HeldTicketResponse create(@Valid @RequestBody HeldTicketDtos.UpsertRequest request) {
        return heldTicketService.upsert(request, null);
    }

    @PatchMapping("/{id}")
    public HeldTicketDtos.HeldTicketResponse update(
            @PathVariable Long id,
            @Valid @RequestBody HeldTicketDtos.UpsertRequest request) {
        return heldTicketService.upsert(request, id);
    }

    @PostMapping("/{id}/split")
    public HeldTicketDtos.SplitResponse split(@PathVariable Long id, @Valid @RequestBody HeldTicketDtos.SplitRequest request) {
        return heldTicketService.split(id, request);
    }

    @PostMapping("/merge")
    public HeldTicketDtos.MergeResponse merge(@Valid @RequestBody HeldTicketDtos.MergeRequest request) {
        return heldTicketService.merge(request);
    }

    @PostMapping("/{id}/move")
    public HeldTicketDtos.MoveResponse move(@PathVariable Long id, @Valid @RequestBody HeldTicketDtos.MoveRequest request) {
        return heldTicketService.move(id, request);
    }

    @PostMapping("/{id}/assign")
    public HeldTicketDtos.AssignResponse assign(
            @PathVariable Long id,
            @Valid @RequestBody HeldTicketDtos.AssignRequest request) {
        return heldTicketService.assign(id, request);
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable Long id) {
        heldTicketService.softDelete(id);
    }
}
