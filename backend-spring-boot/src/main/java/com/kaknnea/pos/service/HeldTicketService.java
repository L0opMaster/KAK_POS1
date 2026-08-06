package com.kaknnea.pos.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kaknnea.pos.domain.PredefinedTicket;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.RestaurantTable;
import com.kaknnea.pos.domain.Sale;
import com.kaknnea.pos.domain.SaleLine;
import com.kaknnea.pos.domain.TicketOperationLog;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.dto.HeldTicketDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.PredefinedTicketRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.ShiftRepository;
import com.kaknnea.pos.repository.TableRepository;
import com.kaknnea.pos.repository.TicketOperationLogRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.DocumentNumberUtil;
import com.kaknnea.pos.util.SecurityUtil;
import jakarta.transaction.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class HeldTicketService {
    private static final Set<String> OPEN_STATUSES = Set.of("HOLD", "IN_PROGRESS", "DRAFT");

    private final SaleRepository saleRepository;
    private final ProductRepository productRepository;
    private final CustomerRepository customerRepository;
    private final ShiftRepository shiftRepository;
    private final TableRepository tableRepository;
    private final UserRepository userRepository;
    private final PredefinedTicketRepository predefinedTicketRepository;
    private final TicketOperationLogRepository ticketOperationLogRepository;
    private ObjectMapper objectMapper;

    public HeldTicketService(SaleRepository saleRepository,
            ProductRepository productRepository,
            CustomerRepository customerRepository,
            ShiftRepository shiftRepository,
            TableRepository tableRepository,
            UserRepository userRepository,
            PredefinedTicketRepository predefinedTicketRepository,
            TicketOperationLogRepository ticketOperationLogRepository,
            ObjectMapper objectMapper) {
        this.saleRepository = saleRepository;
        this.productRepository = productRepository;
        this.customerRepository = customerRepository;
        this.shiftRepository = shiftRepository;
        this.tableRepository = tableRepository;
        this.userRepository = userRepository;
        this.predefinedTicketRepository = predefinedTicketRepository;
        this.ticketOperationLogRepository = ticketOperationLogRepository;
        this.objectMapper = objectMapper;
    }

    public void setObjectMapper(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Transactional
    public List<HeldTicketDtos.HeldTicketResponse> list(String storeId, String terminalId, Long shiftId) {
        return saleRepository.findOpenTickets(shiftId).stream()
                .filter(sale -> matchesScope(sale, storeId, terminalId))
                .map(this::toHeldTicketResponse)
                .toList();
    }

    @Transactional
    public HeldTicketDtos.HeldTicketResponse getById(Long ticketId) {
        return toHeldTicketResponse(requireOpenTicket(ticketId));
    }

    @Transactional
    public HeldTicketDtos.HeldTicketResponse upsert(HeldTicketDtos.UpsertRequest request, Long idOverride) {
        Sale sale = idOverride == null
                ? resolveSaleForUpsert(request)
                : saleRepository.findById(idOverride).orElseThrow(() -> new ApiException("Ticket not found"));
        User currentActor = getCurrentActor();

        if (!OPEN_STATUSES.contains(sale.getStatus()) && sale.getId() != null) {
            throw new ApiException("Only open tickets can be updated");
        }

        sale.setStatus(normalizeOpenStatus(request.getStatus()));
        sale.setDisplayName(request.getDisplayName());
        sale.setComment(request.getComment());
        sale.setTerminalId(request.getTerminalId());

        if (request.getCashierId() != null) {
            User cashier = userRepository.findById(request.getCashierId())
                    .orElseThrow(() -> new ApiException("Cashier not found"));
            sale.setCreatedBy(cashier);
        } else if (sale.getCreatedBy() == null) {
            sale.setCreatedBy(currentActor);
        }

        if (request.getShiftId() != null) {
            sale.setShift(shiftRepository.findById(request.getShiftId())
                    .orElseThrow(() -> new ApiException("Shift not found")));
        } else if (sale.getShift() == null && currentActor != null) {
            sale.setShift(shiftRepository.findFirstByOpenedByIdAndStatusOrderByOpenedAtDesc(
                    currentActor.getId(), "OPEN").orElse(null));
        }

        if (request.getCustomerId() != null) {
            sale.setCustomer(customerRepository.findById(request.getCustomerId())
                    .orElseThrow(() -> new ApiException("Customer not found")));
        } else {
            sale.setCustomer(null);
        }

        if (request.getTableName() != null && !request.getTableName().isBlank()) {
            RestaurantTable newTable = tableRepository.findByTableNumber(request.getTableName()).orElse(null);
            RestaurantTable previousTable = sale.getTable();
            boolean tableChanged = !Objects.equals(
                    newTable == null ? null : newTable.getId(),
                    previousTable == null ? null : previousTable.getId());

            if (tableChanged && newTable != null) {
                assertTableAvailable(newTable, sale.getId());
            }

            sale.setTable(newTable);

            if (tableChanged) {
                markTableOccupied(newTable);
                freeTableIfUnused(previousTable, sale.getId());
            }
        }

        if (request.getAssignedEmployeeId() != null) {
            sale.setAssignedEmployee(userRepository.findById(request.getAssignedEmployeeId())
                    .orElseThrow(() -> new ApiException("Assigned employee not found")));
        } else {
            sale.setAssignedEmployee(null);
        }

        if (request.getPredefinedTicketId() != null) {
            PredefinedTicket slot = predefinedTicketRepository.findById(request.getPredefinedTicketId())
                    .orElseThrow(() -> new ApiException("Predefined ticket not found"));
            assertSlotAvailable(slot.getId(), sale.getId());
            sale.setPredefinedTicket(slot);
        } else {
            sale.setPredefinedTicket(null);
        }

        syncLinesFromRequest(sale, resolveRequestItems(request));
        recalculateTotals(sale);

        Sale saved = saleRepository.save(sale);
        if (saved.getSaleNumber() == null || saved.getSaleNumber().isBlank()) {
            saved.setSaleNumber(defaultCode(saved));
            saved = saleRepository.save(saved);
        }
        logOperation(saved, "UPSERT", null, Map.of("ticketId", saved.getId()));
        return toHeldTicketResponse(saved);
    }

    @Transactional
    public void softDelete(Long ticketId) {
        Sale sale = requireOpenTicket(ticketId);
        RestaurantTable table = sale.getTable();
        sale.setStatus("VOID");
        sale.setClosedReason("VOID");
        saleRepository.save(sale);
        freeTableIfUnused(table, sale.getId());
        logOperation(sale, "DELETE", null, Map.of("ticketId", ticketId, "closedReason", "VOID"));
    }

    @Transactional
    public HeldTicketDtos.SplitResponse split(Long ticketId, HeldTicketDtos.SplitRequest request) {
        if (request.getIdempotencyKey() != null && !request.getIdempotencyKey().isBlank()) {
            TicketOperationLog existing = ticketOperationLogRepository
                    .findFirstByActionAndIdempotencyKeyOrderByIdDesc("SPLIT", request.getIdempotencyKey())
                    .orElse(null);
            if (existing != null) {
                HeldTicketDtos.SplitResponse replay = new HeldTicketDtos.SplitResponse();
                replay.setOriginalTicket(toHeldTicketResponse(requireOpenTicket(ticketId)));
                replay.setCreatedTickets(List.of());
                replay.setOperationId(existing.getId());
                return replay;
            }
        }

        Sale source = requireOpenTicket(ticketId);
        List<HeldTicketDtos.HeldTicketResponse> createdTickets = new ArrayList<>();

        for (HeldTicketDtos.SplitTargetRequest targetRequest : request.getTargets()) {
            Sale target = new Sale();
            target.setStatus("HOLD");
            target.setCreatedBy(source.getCreatedBy());
            target.setShift(source.getShift());
            target.setCustomer(source.getCustomer());
            target.setTable(source.getTable());
            target.setTaxRate(source.getTaxRate());
            target.setCreditTermDays(source.getCreditTermDays());
            target.setDisplayName(targetRequest.getNewTicketName());
            target.setTerminalId(source.getTerminalId());
            target.setComment(source.getComment());
            target.setSubtotal(BigDecimal.ZERO);
            target.setDiscountAmount(BigDecimal.ZERO);
            target.setTaxAmount(BigDecimal.ZERO);
            target.setGrandTotal(BigDecimal.ZERO);
            target.setTotalAmount(BigDecimal.ZERO);
            target.setPaidAmount(BigDecimal.ZERO);
            target.setChangeAmount(BigDecimal.ZERO);

            if (targetRequest.getPredefinedTicketId() != null) {
                PredefinedTicket slot = predefinedTicketRepository.findById(targetRequest.getPredefinedTicketId())
                        .orElseThrow(() -> new ApiException("Predefined ticket not found"));
                assertSlotAvailable(slot.getId(), null);
                target.setPredefinedTicket(slot);
            }

            List<SaleLine> targetLines = new ArrayList<>();
            for (HeldTicketDtos.SplitLineRequest move : targetRequest.getItems()) {
                SaleLine sourceLine = source.getLines().stream()
                        .filter(line -> Objects.equals(line.getId(), move.getLineId()))
                        .findFirst()
                        .orElseThrow(() -> new ApiException("Source line not found: " + move.getLineId()));

                if (move.getQty().compareTo(BigDecimal.ZERO) <= 0 || move.getQty().compareTo(sourceLine.getQuantity()) > 0) {
                    throw new ApiException("Invalid split quantity for line " + move.getLineId());
                }

                BigDecimal originalQty = sourceLine.getQuantity();
                BigDecimal ratio = move.getQty().divide(originalQty, 8, RoundingMode.HALF_UP);
                BigDecimal moveDiscount = sourceLine.getLineDiscount().multiply(ratio).setScale(2, RoundingMode.HALF_UP);

                SaleLine moved = new SaleLine();
                moved.setSale(target);
                moved.setProduct(sourceLine.getProduct());
                moved.setQuantity(move.getQty());
                moved.setUnitPrice(sourceLine.getUnitPrice());
                moved.setLineDiscount(moveDiscount);
                moved.setLineNote(sourceLine.getLineNote());
                moved.setModifierSummary(sourceLine.getModifierSummary());
                moved.setModifierData(sourceLine.getModifierData());
                moved.setLineTotal(sourceLine.getUnitPrice().multiply(move.getQty()).subtract(moveDiscount));
                targetLines.add(moved);

                BigDecimal remainingQty = originalQty.subtract(move.getQty());
                if (remainingQty.compareTo(BigDecimal.ZERO) == 0) {
                    source.getLines().remove(sourceLine);
                } else {
                    sourceLine.setQuantity(remainingQty);
                    sourceLine.setLineDiscount(sourceLine.getLineDiscount().subtract(moveDiscount));
                    sourceLine.setLineTotal(sourceLine.getUnitPrice().multiply(remainingQty)
                            .subtract(sourceLine.getLineDiscount()));
                }
            }

            target.getLines().clear();
            target.getLines().addAll(targetLines);
            recalculateTotals(target);
            Sale created = saleRepository.save(target);
            created.setSaleNumber(defaultCode(created));
            created = saleRepository.save(created);
            createdTickets.add(toHeldTicketResponse(created));
        }

        if (source.getLines().isEmpty()) {
            source.setStatus("VOID");
            source.setClosedReason("VOID");
        }
        recalculateTotals(source);
        Sale sourceSaved = saleRepository.save(source);
        Long operationId = logOperation(sourceSaved, "SPLIT", request.getIdempotencyKey(),
                Map.of("ticketId", ticketId, "createdCount", createdTickets.size()));

        HeldTicketDtos.SplitResponse response = new HeldTicketDtos.SplitResponse();
        response.setOriginalTicket(toHeldTicketResponse(sourceSaved));
        response.setCreatedTickets(createdTickets);
        response.setOperationId(operationId);
        return response;
    }

    @Transactional
    public HeldTicketDtos.MergeResponse merge(HeldTicketDtos.MergeRequest request) {
        if (request.getIdempotencyKey() != null && !request.getIdempotencyKey().isBlank()) {
            TicketOperationLog existing = ticketOperationLogRepository
                    .findFirstByActionAndIdempotencyKeyOrderByIdDesc("MERGE", request.getIdempotencyKey())
                    .orElse(null);
            if (existing != null) {
                Sale target = requireOpenTicket(request.getTargetTicketId());
                HeldTicketDtos.MergeResponse replay = new HeldTicketDtos.MergeResponse();
                replay.setTargetTicket(toHeldTicketResponse(target));
                replay.setMergedSourceIds(List.of());
                replay.setOperationId(existing.getId());
                return replay;
            }
        }

        Sale target = requireOpenTicket(request.getTargetTicketId());
        Set<Long> dedup = new HashSet<>(request.getSourceTicketIds());
        dedup.remove(target.getId());
        if (dedup.isEmpty()) {
            throw new ApiException("At least one source ticket is required");
        }

        List<Long> mergedIds = new ArrayList<>();
        for (Long sourceId : dedup) {
            Sale source = requireOpenTicket(sourceId);
            for (SaleLine line : source.getLines()) {
                SaleLine moved = new SaleLine();
                moved.setSale(target);
                moved.setProduct(line.getProduct());
                moved.setQuantity(line.getQuantity());
                moved.setUnitPrice(line.getUnitPrice());
                moved.setLineDiscount(line.getLineDiscount());
                moved.setLineNote(line.getLineNote());
                moved.setModifierSummary(line.getModifierSummary());
                moved.setModifierData(line.getModifierData());
                moved.setLineTotal(line.getLineTotal());
                target.getLines().add(moved);
            }
            source.getLines().clear();
            source.setStatus("VOID");
            source.setClosedReason("MERGED");
            recalculateTotals(source);
            saleRepository.save(source);
            mergedIds.add(sourceId);
        }

        recalculateTotals(target);
        Sale savedTarget = saleRepository.save(target);
        Long operationId = logOperation(savedTarget, "MERGE", request.getIdempotencyKey(),
                Map.of("targetTicketId", target.getId(), "sourceTicketIds", mergedIds));

        HeldTicketDtos.MergeResponse response = new HeldTicketDtos.MergeResponse();
        response.setTargetTicket(toHeldTicketResponse(savedTarget));
        response.setMergedSourceIds(mergedIds);
        response.setOperationId(operationId);
        return response;
    }

    @Transactional
    public HeldTicketDtos.MoveResponse move(Long ticketId, HeldTicketDtos.MoveRequest request) {
        Sale ticket = requireOpenTicket(ticketId);
        PredefinedTicket slot = predefinedTicketRepository.findById(request.getTargetPredefinedTicketId())
                .orElseThrow(() -> new ApiException("Predefined ticket not found"));
        assertSlotAvailable(slot.getId(), ticketId);
        ticket.setPredefinedTicket(slot);
        Sale saved = saleRepository.save(ticket);
        Long operationId = logOperation(saved, "MOVE", null,
                Map.of("ticketId", ticketId, "predefinedTicketId", slot.getId()));

        HeldTicketDtos.MoveResponse response = new HeldTicketDtos.MoveResponse();
        response.setTicket(toHeldTicketResponse(saved));
        response.setOperationId(operationId);
        return response;
    }

    @Transactional
    public HeldTicketDtos.AssignResponse assign(Long ticketId, HeldTicketDtos.AssignRequest request) {
        Sale ticket = requireOpenTicket(ticketId);
        User assignee = null;
        if (request.getAssignedEmployeeId() != null) {
            assignee = userRepository.findById(request.getAssignedEmployeeId())
                    .orElseThrow(() -> new ApiException("Assigned employee not found"));
        }
        ticket.setAssignedEmployee(assignee);
        Sale saved = saleRepository.save(ticket);
        Long operationId = logOperation(saved, "ASSIGN", null,
                Map.of("ticketId", ticketId, "assignedEmployeeId", request.getAssignedEmployeeId()));

        HeldTicketDtos.AssignResponse response = new HeldTicketDtos.AssignResponse();
        response.setTicket(toHeldTicketResponse(saved));
        response.setOperationId(operationId);
        return response;
    }

    @Transactional
    public List<HeldTicketDtos.PredefinedTicketResponse> listPredefined(String storeId, String terminalId) {
        List<PredefinedTicket> rows = terminalId == null || terminalId.isBlank()
                ? predefinedTicketRepository.findByStoreIdAndActiveTrueOrderBySortOrderAscIdAsc(storeId)
                : predefinedTicketRepository.findByStoreIdAndTerminalIdAndActiveTrueOrderBySortOrderAscIdAsc(
                        storeId,
                        terminalId);
        return rows.stream().map(this::toPredefinedResponse).toList();
    }

    @Transactional
    public HeldTicketDtos.PredefinedTicketResponse createPredefined(HeldTicketDtos.PredefinedTicketRequest request) {
        PredefinedTicket slot = new PredefinedTicket();
        slot.setStoreId(request.getStoreId());
        slot.setTerminalId(request.getTerminalId());
        slot.setName(request.getName());
        slot.setSortOrder(request.getSortOrder());
        slot.setActive(request.getActive() == null || request.getActive());
        return toPredefinedResponse(predefinedTicketRepository.save(slot));
    }

    @Transactional
    public HeldTicketDtos.PredefinedTicketResponse updatePredefined(Long id, HeldTicketDtos.PredefinedTicketRequest request) {
        PredefinedTicket slot = predefinedTicketRepository.findById(id)
                .orElseThrow(() -> new ApiException("Predefined ticket not found"));
        slot.setStoreId(request.getStoreId());
        slot.setTerminalId(request.getTerminalId());
        slot.setName(request.getName());
        slot.setSortOrder(request.getSortOrder());
        slot.setActive(request.getActive() == null || request.getActive());
        return toPredefinedResponse(predefinedTicketRepository.save(slot));
    }

    @Transactional
    public void deletePredefined(Long id) {
        PredefinedTicket slot = predefinedTicketRepository.findById(id)
                .orElseThrow(() -> new ApiException("Predefined ticket not found"));
        long count = saleRepository.countActiveByPredefinedTicketId(slot.getId());
        if (count > 0) {
            throw new ApiException("Cannot delete occupied predefined ticket");
        }
        predefinedTicketRepository.delete(slot);
    }

    @Transactional
    public List<HeldTicketDtos.OccupancyResponse> occupancy(String storeId, String terminalId) {
        List<PredefinedTicket> slots = terminalId == null || terminalId.isBlank()
                ? predefinedTicketRepository.findByStoreIdAndActiveTrueOrderBySortOrderAscIdAsc(storeId)
                : predefinedTicketRepository.findByStoreIdAndTerminalIdAndActiveTrueOrderBySortOrderAscIdAsc(
                        storeId,
                        terminalId);
        List<Sale> activeTickets = saleRepository.findOpenTickets(null).stream()
                .filter(sale -> sale.getPredefinedTicket() != null)
                .toList();

        Map<Long, Sale> occupied = activeTickets.stream()
                .collect(Collectors.toMap(s -> s.getPredefinedTicket().getId(), s -> s, (a, b) -> a));

        return slots.stream().map(slot -> {
            Sale ticket = occupied.get(slot.getId());
            HeldTicketDtos.OccupancyResponse row = new HeldTicketDtos.OccupancyResponse();
            row.setPredefinedTicketId(slot.getId());
            row.setName(slot.getName());
            row.setOccupied(ticket != null);
            row.setTicketId(ticket == null ? null : ticket.getId());
            row.setTicketCode(ticket == null ? null : defaultCode(ticket));
            return row;
        }).toList();
    }

    private Sale resolveSaleForUpsert(HeldTicketDtos.UpsertRequest request) {
        if (request.getId() != null) {
            return saleRepository.findById(request.getId()).orElseThrow(() -> new ApiException("Ticket not found"));
        }
        Sale sale = new Sale();
        sale.setStatus(normalizeOpenStatus(request.getStatus()));
        sale.setSubtotal(BigDecimal.ZERO);
        sale.setDiscountAmount(BigDecimal.ZERO);
        sale.setTaxRate(0);
        sale.setTaxAmount(BigDecimal.ZERO);
        sale.setGrandTotal(BigDecimal.ZERO);
        sale.setTotalAmount(BigDecimal.ZERO);
        sale.setPaidAmount(BigDecimal.ZERO);
        sale.setChangeAmount(BigDecimal.ZERO);
        return sale;
    }

    private boolean matchesScope(Sale sale, String storeId, String terminalId) {
        if (storeId == null || storeId.isBlank()) {
            return true;
        }
        String saleStore = sale.getPredefinedTicket() == null ? null : sale.getPredefinedTicket().getStoreId();
        if (saleStore != null && !saleStore.equals(storeId)) {
            return false;
        }
        if (terminalId == null || terminalId.isBlank()) {
            return true;
        }
        if (sale.getTerminalId() != null) {
            return sale.getTerminalId().equals(terminalId);
        }
        String scopedTerminal = sale.getPredefinedTicket() == null ? null : sale.getPredefinedTicket().getTerminalId();
        return scopedTerminal == null || scopedTerminal.equals(terminalId);
    }

    private void syncLinesFromRequest(Sale sale, List<HeldTicketDtos.LineRequest> items) {
        List<SaleLine> updatedLines = new ArrayList<>();
        for (HeldTicketDtos.LineRequest req : items) {
            Product product = productRepository.findById(req.getProduct().getId())
                    .orElseThrow(() -> new ApiException("Product not found: " + req.getProduct().getId()));
            SaleLine line = new SaleLine();
            line.setSale(sale);
            line.setProduct(product);
            line.setQuantity(req.getQty());
            BigDecimal baseUnitPrice = req.getUnitPrice() != null ? req.getUnitPrice()
                    : (req.getProduct().getPrice() != null ? req.getProduct().getPrice() : BigDecimal.ZERO);
            BigDecimal unitPrice = baseUnitPrice.add(modifierPriceDelta(req.getSelectedModifiers()));
            line.setUnitPrice(unitPrice);
            BigDecimal discount = req.getDiscount() == null ? BigDecimal.ZERO : req.getDiscount();
            line.setLineDiscount(discount);
            line.setLineNote(req.getNote());
            line.setModifierSummary(buildModifierSummary(req.getSelectedModifiers()));
            line.setModifierData(modifierDataJson(req.getSelectedModifiers()));
            line.setLineTotal(unitPrice.multiply(req.getQty()).subtract(discount));
            updatedLines.add(line);
        }
        sale.getLines().clear();
        sale.getLines().addAll(updatedLines);
    }

    /** Sums the `priceDelta` of every selected modifier option on a held-ticket line. */
    private BigDecimal modifierPriceDelta(List<HeldTicketDtos.SelectedModifierPayload> selections) {
        if (selections == null || selections.isEmpty()) {
            return BigDecimal.ZERO;
        }
        BigDecimal total = BigDecimal.ZERO;
        for (HeldTicketDtos.SelectedModifierPayload selection : selections) {
            if (selection != null && selection.getPriceDelta() != null) {
                total = total.add(selection.getPriceDelta());
            }
        }
        return total;
    }

    /** Builds a human-readable summary like `"Sugar Level: 50%"`, grouped by modifier group. */
    private String buildModifierSummary(List<HeldTicketDtos.SelectedModifierPayload> selections) {
        if (selections == null || selections.isEmpty()) {
            return null;
        }
        Map<String, List<String>> byGroup = new LinkedHashMap<>();
        for (HeldTicketDtos.SelectedModifierPayload selection : selections) {
            if (selection == null) {
                continue;
            }
            String groupName = selection.getGroupName() == null ? "" : selection.getGroupName();
            byGroup.computeIfAbsent(groupName, key -> new ArrayList<>())
                    .add(selection.getOptionName() == null ? "" : selection.getOptionName());
        }
        return byGroup.entrySet().stream()
                .map(entry -> entry.getKey() + ": " + String.join(", ", entry.getValue()))
                .collect(Collectors.joining(", "));
    }

    /** Serializes selected modifiers to the same JSON contract `SaleLine.modifierData` uses elsewhere. */
    private String modifierDataJson(List<HeldTicketDtos.SelectedModifierPayload> selections) {
        if (selections == null || selections.isEmpty()) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(selections);
        } catch (JsonProcessingException e) {
            return null;
        }
    }

    /** Reverses [modifierDataJson] for the response side, so resuming a ticket restores the same selections. */
    private List<HeldTicketDtos.SelectedModifierPayload> parseModifierData(String modifierDataJson) {
        if (modifierDataJson == null || modifierDataJson.isBlank()) {
            return null;
        }
        try {
            return objectMapper.readValue(modifierDataJson,
                    objectMapper.getTypeFactory().constructCollectionType(
                            List.class, HeldTicketDtos.SelectedModifierPayload.class));
        } catch (Exception e) {
            return null;
        }
    }

    private void recalculateTotals(Sale sale) {
        BigDecimal subtotal = sale.getLines().stream()
                .map(line -> line.getUnitPrice().multiply(line.getQuantity()))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);
        BigDecimal discount = sale.getLines().stream()
                .map(line -> line.getLineDiscount() == null ? BigDecimal.ZERO : line.getLineDiscount())
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);
        BigDecimal taxable = subtotal.subtract(discount).max(BigDecimal.ZERO);
        BigDecimal tax = taxable.multiply(BigDecimal.valueOf(sale.getTaxRate())).setScale(2, RoundingMode.HALF_UP);
        BigDecimal grandTotal = taxable.add(tax).setScale(2, RoundingMode.HALF_UP);

        sale.setSubtotal(subtotal);
        sale.setDiscountAmount(discount);
        sale.setTaxAmount(tax);
        sale.setGrandTotal(grandTotal);
        sale.setTotalAmount(grandTotal);
        if (sale.getPaidAmount() == null) {
            sale.setPaidAmount(BigDecimal.ZERO);
        }
        if (sale.getPaidAmount().compareTo(grandTotal) > 0) {
            sale.setPaidAmount(grandTotal);
        }
        if (sale.getChangeAmount() == null) {
            sale.setChangeAmount(BigDecimal.ZERO);
        }
    }

    private HeldTicketDtos.HeldTicketResponse toHeldTicketResponse(Sale sale) {
        HeldTicketDtos.HeldTicketResponse response = new HeldTicketDtos.HeldTicketResponse();
        response.setId(sale.getId());
        response.setCode(defaultCode(sale));
        response.setStatus(sale.getStatus());
        response.setTotal(sale.getGrandTotal() == null ? BigDecimal.ZERO : sale.getGrandTotal());
        response.setCreatedAt(sale.getCreatedAt() == null ? Instant.now().toString() : sale.getCreatedAt().toString());
        response.setUpdatedAt(sale.getUpdatedAt() == null
                ? response.getCreatedAt()
                : sale.getUpdatedAt().toString());
        List<HeldTicketDtos.LineResponse> lines = sale.getLines().stream().map(this::toLineResponse).toList();
        response.setItems(lines);
        response.setCart(lines);
        response.setTableName(sale.getTable() == null ? null : sale.getTable().getTableNumber());
        response.setStoreId(sale.getPredefinedTicket() == null ? null : sale.getPredefinedTicket().getStoreId());
        response.setTerminalId(sale.getTerminalId() != null
                ? sale.getTerminalId()
                : (sale.getPredefinedTicket() == null ? null : sale.getPredefinedTicket().getTerminalId()));
        response.setShiftId(sale.getShift() == null ? null : sale.getShift().getId());
        response.setCashierId(sale.getCreatedBy() == null ? null : sale.getCreatedBy().getId());
        response.setCustomerId(sale.getCustomer() == null ? null : sale.getCustomer().getId());
        response.setLockedBy(null);
        response.setLockExpiresAt(null);
        response.setVersion(sale.getVersion());
        response.setDisplayName(sale.getDisplayName());
        response.setComment(sale.getComment());
        response.setAssignedEmployeeId(sale.getAssignedEmployee() == null ? null : sale.getAssignedEmployee().getId());
        response.setPredefinedTicketId(sale.getPredefinedTicket() == null ? null : sale.getPredefinedTicket().getId());
        response.setClosedReason(sale.getClosedReason());
        return response;
    }

    private HeldTicketDtos.LineResponse toLineResponse(SaleLine line) {
        HeldTicketDtos.LineResponse row = new HeldTicketDtos.LineResponse();
        row.setId(String.valueOf(line.getId()));
        row.setQty(line.getQuantity().setScale(0, RoundingMode.HALF_UP).intValue());
        row.setDiscount(line.getLineDiscount() == null ? 0d : line.getLineDiscount().doubleValue());
        row.setUnitPrice(line.getUnitPrice().doubleValue());
        row.setNote(line.getLineNote());
        row.setAddedAt(Instant.now().toEpochMilli());
        row.setSelectedModifiers(parseModifierData(line.getModifierData()));

        HeldTicketDtos.ProductResponse product = new HeldTicketDtos.ProductResponse();
        product.setId(line.getProduct().getId());
        product.setSku(line.getProduct().getSku());
        product.setBarcode(line.getProduct().getBarcode());
        product.setNameEn(line.getProduct().getNameEn());
        product.setNameKm(line.getProduct().getNameKm());
        // Base catalog price only — NOT line.getUnitPrice(), which already has the
        // modifier delta baked in. The POS frontend's CartItem.unitPrice getter
        // adds selectedModifiers' priceDelta on top of product.price everywhere
        // (add-to-cart, cart totals, receipts, ...); resuming a ticket must follow
        // the same rule, or the modifier surcharge would be counted twice here.
        product.setPrice(line.getProduct().getPrice() != null ? line.getProduct().getPrice().doubleValue() : 0d);
        row.setProduct(product);
        return row;
    }

    private HeldTicketDtos.PredefinedTicketResponse toPredefinedResponse(PredefinedTicket slot) {
        HeldTicketDtos.PredefinedTicketResponse response = new HeldTicketDtos.PredefinedTicketResponse();
        response.setId(slot.getId());
        response.setStoreId(slot.getStoreId());
        response.setTerminalId(slot.getTerminalId());
        response.setName(slot.getName());
        response.setSortOrder(slot.getSortOrder());
        response.setActive(slot.isActive());
        return response;
    }

    private Sale requireOpenTicket(Long id) {
        Sale sale = saleRepository.findById(id).orElseThrow(() -> new ApiException("Ticket not found"));
        if (!OPEN_STATUSES.contains(sale.getStatus())) {
            throw new ApiException("Ticket is not open");
        }
        return sale;
    }

    private void assertSlotAvailable(Long predefinedTicketId, Long excludeTicketId) {
        long occupied = saleRepository.countActiveByPredefinedTicketIdExcluding(predefinedTicketId, excludeTicketId);
        if (occupied > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Predefined ticket slot is occupied");
        }
    }

    /**
     * Guards against two open tickets holding the same table at once. This
     * backs up the client-side check in the table picker (which already
     * hides non-AVAILABLE tables) for races between terminals.
     */
    private void assertTableAvailable(RestaurantTable table, Long excludeSaleId) {
        long occupied = saleRepository.countActiveByTableIdExcluding(table.getId(), excludeSaleId);
        if (occupied > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Table is already in use by another open ticket");
        }
    }

    /** Marks a table OCCUPIED once a ticket starts holding it. Leaves RESERVED/OUT_OF_ORDER alone. */
    private void markTableOccupied(RestaurantTable table) {
        if (table != null && "AVAILABLE".equals(table.getStatus())) {
            table.setStatus("OCCUPIED");
            tableRepository.save(table);
        }
    }

    /**
     * Frees a table back to AVAILABLE once no other open ticket still holds
     * it (voided/paid tickets don't count — see OPEN_STATUSES). Leaves
     * RESERVED/OUT_OF_ORDER alone since those are set manually, not by this
     * occupancy tracking.
     */
    private void freeTableIfUnused(RestaurantTable table, Long excludeSaleId) {
        if (table == null || !"OCCUPIED".equals(table.getStatus())) {
            return;
        }
        long stillActive = saleRepository.countActiveByTableIdExcluding(table.getId(), excludeSaleId);
        if (stillActive == 0) {
            table.setStatus("AVAILABLE");
            tableRepository.save(table);
        }
    }

    private Long logOperation(Sale ticket, String action, String idempotencyKey, Object payload) {
        TicketOperationLog op = new TicketOperationLog();
        op.setTicket(ticket);
        op.setAction(action);
        op.setIdempotencyKey(idempotencyKey);
        op.setActor(getCurrentActor());
        op.setPayloadJson(toJson(payload));
        return ticketOperationLogRepository.save(op).getId();
    }

    private String toJson(Object payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            Map<String, String> fallback = new HashMap<>();
            fallback.put("error", "serialization_failed");
            fallback.put("message", e.getMessage());
            return fallback.toString();
        }
    }

    private User getCurrentActor() {
        String username = SecurityUtil.currentUsername();
        return userRepository.findByEmail(username).orElse(null);
    }

    private String normalizeOpenStatus(String status) {
        if (status == null || status.isBlank()) {
            return "HOLD";
        }
        String normalized = status.trim().toUpperCase();
        if (!OPEN_STATUSES.contains(normalized)) {
            return "HOLD";
        }
        return normalized;
    }

    private String defaultCode(Sale sale) {
        return DocumentNumberUtil.heldTicketNumber(sale);
    }

    private List<HeldTicketDtos.LineRequest> resolveRequestItems(HeldTicketDtos.UpsertRequest request) {
        if (request.getItems() != null) {
            return request.getItems();
        }
        if (request.getCart() != null) {
            return request.getCart();
        }
        return Collections.emptyList();
    }
}
