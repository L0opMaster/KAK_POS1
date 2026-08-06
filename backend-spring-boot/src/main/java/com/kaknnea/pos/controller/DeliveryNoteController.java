package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.DeliveryNoteDtos;
import com.kaknnea.pos.service.DeliveryNoteService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/delivery-notes")
public class DeliveryNoteController {
    private final DeliveryNoteService deliveryNoteService;

    public DeliveryNoteController(DeliveryNoteService deliveryNoteService) {
        this.deliveryNoteService = deliveryNoteService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasAuthority('PERM_CUSTOMER_MANAGE')")
    public List<DeliveryNoteDtos.DeliveryNoteResponse> list() {
        return deliveryNoteService.list();
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public DeliveryNoteDtos.DeliveryNoteResponse create(@Valid @RequestBody DeliveryNoteDtos.DeliveryNoteRequest request) {
        return deliveryNoteService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public DeliveryNoteDtos.DeliveryNoteResponse updateStatus(
            @PathVariable Long id,
            @Valid @RequestBody DeliveryNoteDtos.DeliveryNoteStatusRequest request) {
        return deliveryNoteService.updateStatus(id, request.getStatus());
    }

    @PutMapping("/{id}/details")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public DeliveryNoteDtos.DeliveryNoteResponse updateDetails(
            @PathVariable Long id,
            @Valid @RequestBody DeliveryNoteDtos.DeliveryNoteRequest request) {
        return deliveryNoteService.update(id, request);
    }
}
