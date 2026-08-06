package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.CashEvent;
import com.kaknnea.pos.domain.Sale;
import com.kaknnea.pos.domain.Shift;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.dto.CashEventDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.CashEventRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.ShiftRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.SecurityUtil;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class CashEventService {
    private final CashEventRepository cashEventRepository;
    private final ShiftRepository shiftRepository;
    private final SaleRepository saleRepository;
    private final UserRepository userRepository;
    private final AuditService auditService;

    public CashEventService(
            CashEventRepository cashEventRepository,
            ShiftRepository shiftRepository,
            SaleRepository saleRepository,
            UserRepository userRepository,
            AuditService auditService) {
        this.cashEventRepository = cashEventRepository;
        this.shiftRepository = shiftRepository;
        this.saleRepository = saleRepository;
        this.userRepository = userRepository;
        this.auditService = auditService;
    }

    public List<CashEventDtos.CashEventResponse> listByShift(Long shiftId) {
        return cashEventRepository.findByShiftIdOrderByCreatedAtDesc(shiftId)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public CashEventDtos.CashEventResponse create(Long shiftId, CashEventDtos.CashEventRequest request) {
        Shift shift = shiftRepository.findById(shiftId).orElseThrow(() -> new ApiException("Shift not found"));
        User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);

        CashEvent event = new CashEvent();
        event.setShift(shift);
        event.setType(request.getType().trim().toUpperCase());
        event.setAmount(request.getAmount());
        event.setReason(request.getReason());
        event.setCreatedAt(Instant.now());
        event.setUser(actor);

        if (request.getSaleId() != null) {
            Sale sale = saleRepository.findById(request.getSaleId())
                    .orElseThrow(() -> new ApiException("Sale not found"));
            event.setSale(sale);
        }

        CashEvent saved = cashEventRepository.save(event);
        auditService.log(actor, "CASH_EVENT", "CashEvent", String.valueOf(saved.getId()), null, saved);
        return toResponse(saved);
    }

    @Transactional
    public void recordInternal(
            Shift shift,
            String type,
            java.math.BigDecimal amount,
            String reason,
            Sale sale,
            User actor) {
        if (shift == null || type == null || type.isBlank()) {
            return;
        }

        CashEvent event = new CashEvent();
        event.setShift(shift);
        event.setType(type.trim().toUpperCase());
        event.setAmount(amount == null ? java.math.BigDecimal.ZERO : amount);
        event.setReason(reason);
        event.setSale(sale);
        event.setUser(actor);
        event.setCreatedAt(Instant.now());

        CashEvent saved = cashEventRepository.save(event);
        auditService.log(actor, "CASH_EVENT_INTERNAL", "CashEvent", String.valueOf(saved.getId()), null, saved);
    }

    private CashEventDtos.CashEventResponse toResponse(CashEvent event) {
        CashEventDtos.CashEventResponse response = new CashEventDtos.CashEventResponse();
        response.setId(event.getId());
        response.setShiftId(event.getShift() != null ? event.getShift().getId() : null);
        response.setType(event.getType());
        response.setAmount(event.getAmount());
        response.setReason(event.getReason());
        response.setSaleId(event.getSale() != null ? event.getSale().getId() : null);
        response.setCreatedAt(event.getCreatedAt());
        response.setUserId(event.getUser() != null ? event.getUser().getId() : null);
        return response;
    }
}
