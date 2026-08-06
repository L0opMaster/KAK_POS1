package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.HeldTicketDtos;
import com.kaknnea.pos.service.HeldTicketService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/pos/predefined-tickets")
@PreAuthorize("hasAnyRole('CASHIER','MANAGER','OWNER')")
public class PredefinedTicketController {
    private final HeldTicketService heldTicketService;

    public PredefinedTicketController(HeldTicketService heldTicketService) {
        this.heldTicketService = heldTicketService;
    }

    @GetMapping
    public List<HeldTicketDtos.PredefinedTicketResponse> list(
            @RequestParam String storeId,
            @RequestParam(required = false) String terminalId) {
        return heldTicketService.listPredefined(storeId, terminalId);
    }

    @PostMapping
    public HeldTicketDtos.PredefinedTicketResponse create(
            @Valid @RequestBody HeldTicketDtos.PredefinedTicketRequest request) {
        return heldTicketService.createPredefined(request);
    }

    @PutMapping("/{id}")
    public HeldTicketDtos.PredefinedTicketResponse update(
            @PathVariable Long id,
            @Valid @RequestBody HeldTicketDtos.PredefinedTicketRequest request) {
        return heldTicketService.updatePredefined(id, request);
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable Long id) {
        heldTicketService.deletePredefined(id);
    }

    @GetMapping("/occupancy")
    public List<HeldTicketDtos.OccupancyResponse> occupancy(
            @RequestParam String storeId,
            @RequestParam(required = false) String terminalId) {
        return heldTicketService.occupancy(storeId, terminalId);
    }
}
