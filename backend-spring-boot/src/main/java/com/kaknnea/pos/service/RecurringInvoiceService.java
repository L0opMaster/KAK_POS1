package com.kaknnea.pos.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kaknnea.pos.domain.RecurringInvoiceTemplate;
import com.kaknnea.pos.dto.RecurringInvoiceDtos;
import com.kaknnea.pos.dto.SaleDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.RecurringInvoiceTemplateRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class RecurringInvoiceService {

    private static final Logger log = LoggerFactory.getLogger(RecurringInvoiceService.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final RecurringInvoiceTemplateRepository templateRepository;
    private final CustomerRepository customerRepository;
    private final SaleService saleService;

    public RecurringInvoiceService(RecurringInvoiceTemplateRepository templateRepository,
                                   CustomerRepository customerRepository,
                                   SaleService saleService) {
        this.templateRepository = templateRepository;
        this.customerRepository = customerRepository;
        this.saleService = saleService;
    }

    // ──────────────────────────────────────────────
    //  CRUD
    // ──────────────────────────────────────────────

    public List<RecurringInvoiceDtos.TemplateResponse> listAll() {
        return templateRepository.findByActiveTrueOrderByNextRunDateAsc()
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    public RecurringInvoiceDtos.TemplateResponse getById(Long id) {
        var template = templateRepository.findById(id)
                .orElseThrow(() -> new ApiException("Recurring template not found"));
        return toResponse(template);
    }

    @Transactional
    public RecurringInvoiceDtos.TemplateResponse create(RecurringInvoiceDtos.CreateRequest request) {
        var template = new RecurringInvoiceTemplate();
        applyCreateRequest(template, request);
        template.setNextRunDate(parseDate(request.getNextRunDate(), LocalDate.now()));
        if (request.getEndDate() != null) {
            template.setEndDate(parseDate(request.getEndDate(), null));
        }
        template.setOccurrencesCount(0);
        template.setActive(true);
        template.setLinesJson(toJson(request.getLines()));
        var saved = templateRepository.save(template);
        log.info("Created recurring invoice template: id={}, name={}, frequency={}",
                saved.getId(), saved.getName(), saved.getFrequency());
        return toResponse(saved);
    }

    @Transactional
    public RecurringInvoiceDtos.TemplateResponse update(Long id, RecurringInvoiceDtos.UpdateRequest request) {
        var template = templateRepository.findById(id)
                .orElseThrow(() -> new ApiException("Recurring template not found"));

        if (request.getName() != null) template.setName(request.getName());
        if (request.getDescription() != null) template.setDescription(request.getDescription());
        if (request.getFrequency() != null) template.setFrequency(request.getFrequency());
        if (request.getIntervalCount() != null) template.setIntervalCount(request.getIntervalCount());
        if (request.getDayOfWeek() != null) template.setDayOfWeek(request.getDayOfWeek());
        if (request.getDayOfMonth() != null) template.setDayOfMonth(request.getDayOfMonth());
        if (request.getMonthOfYear() != null) template.setMonthOfYear(request.getMonthOfYear());
        if (request.getNextRunDate() != null) template.setNextRunDate(parseDate(request.getNextRunDate(), template.getNextRunDate()));
        if (request.getEndDate() != null) template.setEndDate(parseDate(request.getEndDate(), template.getEndDate()));
        if (request.getMaxOccurrences() != null) template.setMaxOccurrences(request.getMaxOccurrences());
        if (request.getActive() != null) template.setActive(request.getActive());
        if (request.getCustomerId() != null) template.setCustomerId(request.getCustomerId());
        if (request.getDisplayName() != null) template.setDisplayName(request.getDisplayName());
        if (request.getPaymentTerms() != null) template.setPaymentTerms(request.getPaymentTerms());
        if (request.getDeliveryCharge() != null) template.setDeliveryCharge(request.getDeliveryCharge());
        if (request.getOtherCharge() != null) template.setOtherCharge(request.getOtherCharge());
        if (request.getDepositAmount() != null) template.setDepositAmount(request.getDepositAmount());
        if (request.getNote() != null) template.setNote(request.getNote());
        if (request.getInvoiceDiscount() != null) template.setInvoiceDiscount(request.getInvoiceDiscount());
        if (request.getTaxRate() != null) template.setTaxRate(request.getTaxRate());
        if (request.getDeliveryRecipientName() != null) template.setDeliveryRecipientName(request.getDeliveryRecipientName());
        if (request.getDeliveryPhone() != null) template.setDeliveryPhone(request.getDeliveryPhone());
        if (request.getDeliveryAddress() != null) template.setDeliveryAddress(request.getDeliveryAddress());
        if (request.getLines() != null) template.setLinesJson(toJson(request.getLines()));

        var saved = templateRepository.save(template);
        return toResponse(saved);
    }

    @Transactional
    public void delete(Long id) {
        var template = templateRepository.findById(id)
                .orElseThrow(() -> new ApiException("Recurring template not found"));
        template.setActive(false);
        templateRepository.save(template);
        log.info("Deactivated recurring template: id={}", id);
    }

    // ──────────────────────────────────────────────
    //  Invoice Generation (called by scheduler)
    // ──────────────────────────────────────────────

    @Transactional
    public int generateDueInvoices() {
        List<RecurringInvoiceTemplate> dueTemplates = templateRepository
                .findByActiveTrueAndNextRunDateLessThanEqual(LocalDate.now());

        int generated = 0;
        for (var template : dueTemplates) {
            try {
                generateInvoice(template);
                generated++;
            } catch (Exception e) {
                log.error("Failed to generate invoice from template id={}: {}", template.getId(), e.getMessage(), e);
            }
        }
        if (generated > 0) {
            log.info("Recurring invoice generation complete: {} invoices created", generated);
        }
        return generated;
    }

    private void generateInvoice(RecurringInvoiceTemplate template) {
        // Build the sale create request from the template
        var request = new SaleDtos.SaleCreateRequest();
        request.setCustomerId(template.getCustomerId());
        request.setDisplayName(template.getDisplayName());
        request.setOrderDate(LocalDate.now().toString());
        request.setDeliveryDate(template.getNextRunDate().toString());
        request.setPaymentTerms(template.getPaymentTerms());
        request.setDeliveryCharge(template.getDeliveryCharge());
        request.setOtherCharge(template.getOtherCharge());
        request.setDepositAmount(template.getDepositAmount());
        request.setNote(template.getNote());
        request.setInvoiceDiscount(template.getInvoiceDiscount());
        request.setTaxRate(template.getTaxRate());
        request.setDeliveryRecipientName(template.getDeliveryRecipientName());
        request.setDeliveryPhone(template.getDeliveryPhone());
        request.setDeliveryAddress(template.getDeliveryAddress());

        // Parse and set line items from JSON
        try {
            List<RecurringInvoiceDtos.RecurringLineItem> lines = parseLines(template.getLinesJson());
            request.setLines(lines.stream().map(line -> {
                var lineReq = new SaleDtos.SaleLineRequest();
                lineReq.setProductId(line.getProductId());
                lineReq.setQuantity(line.getQuantity());
                lineReq.setUnitPrice(line.getUnitPrice());
                lineReq.setLineDiscount(line.getLineDiscount());
                lineReq.setNote(line.getNote());
                return lineReq;
            }).collect(Collectors.toList()));
        } catch (Exception e) {
            throw new ApiException("Failed to parse line items for template " + template.getId() + ": " + e.getMessage());
        }

        // Create the sale (DRAFT initially)
        var created = saleService.create(request);

        // Update template tracking
        template.setOccurrencesCount(template.getOccurrencesCount() + 1);
        template.setLastGeneratedAt(Instant.now());
        template.setLastInvoiceId(created.getId());

        // Calculate next run date
        template.setNextRunDate(calculateNextRunDate(template));

        // Check if we should deactivate
        if (shouldDeactivate(template)) {
            template.setActive(false);
        }

        templateRepository.save(template);
        log.info("Generated invoice id={} from recurring template id={} (occurrence #{})",
                created.getId(), template.getId(), template.getOccurrencesCount());
    }

    private LocalDate calculateNextRunDate(RecurringInvoiceTemplate template) {
        LocalDate current = template.getNextRunDate();
        int interval = Math.max(1, template.getIntervalCount());

        return switch (template.getFrequency().toUpperCase()) {
            case "DAILY" -> current.plusDays(interval);
            case "WEEKLY" -> advanceToDayOfWeek(current.plusWeeks(interval), template.getDayOfWeek());
            case "MONTHLY" -> advanceToDayOfMonth(current.plusMonths(interval), template.getDayOfMonth());
            case "YEARLY" -> advanceToDayOfMonthYear(
                    current.plusYears(interval),
                    template.getMonthOfYear(),
                    template.getDayOfMonth());
            default -> current.plusMonths(1); // fallback
        };
    }

    private LocalDate advanceToDayOfWeek(LocalDate date, Integer targetDay) {
        if (targetDay == null) return date;
        int diff = targetDay - date.getDayOfWeek().getValue(); // Monday=1, Sunday=7
        if (diff < 0) diff += 7;
        // Convert from Mon=1..Sun=7 to Sun=0..Sat=6
        int currentDow = date.getDayOfWeek().getValue() % 7; // Sun=0
        int targetDow = targetDay % 7;
        int daysUntil = (targetDow - currentDow + 7) % 7;
        return daysUntil == 0 ? date : date.plusDays(daysUntil);
    }

    private LocalDate advanceToDayOfMonth(LocalDate date, Integer targetDay) {
        if (targetDay == null || targetDay < 1) return date;
        int lastDay = date.lengthOfMonth();
        int day = Math.min(targetDay, lastDay);
        return date.withDayOfMonth(day);
    }

    private LocalDate advanceToDayOfMonthYear(LocalDate date, Integer targetMonth, Integer targetDay) {
        if (targetMonth == null || targetMonth < 1 || targetMonth > 12) return date;
        LocalDate monthDate = date.withMonth(targetMonth);
        if (targetDay != null && targetDay >= 1) {
            int lastDay = monthDate.lengthOfMonth();
            return monthDate.withDayOfMonth(Math.min(targetDay, lastDay));
        }
        return monthDate;
    }

    private boolean shouldDeactivate(RecurringInvoiceTemplate template) {
        if (template.getEndDate() != null && LocalDate.now().isAfter(template.getEndDate())) {
            return true;
        }
        if (template.getMaxOccurrences() != null && template.getOccurrencesCount() >= template.getMaxOccurrences()) {
            return true;
        }
        return false;
    }

    // ──────────────────────────────────────────────
    //  Scheduling (runs daily at 2:00 AM)
    // ──────────────────────────────────────────────

    @Scheduled(cron = "0 0 2 * * ?")
    @Transactional
    public void scheduledGeneration() {
        log.info("Recurring invoice scheduler running...");
        int count = generateDueInvoices();
        if (count > 0) {
            log.info("Scheduled generation complete: {} invoices created", count);
        }
    }

    // ──────────────────────────────────────────────
    //  Helpers
    // ──────────────────────────────────────────────

    private void applyCreateRequest(RecurringInvoiceTemplate template, RecurringInvoiceDtos.CreateRequest req) {
        template.setName(req.getName());
        template.setDescription(req.getDescription());
        template.setFrequency(req.getFrequency());
        template.setIntervalCount(req.getIntervalCount());
        template.setDayOfWeek(req.getDayOfWeek());
        template.setDayOfMonth(req.getDayOfMonth());
        template.setMonthOfYear(req.getMonthOfYear());
        template.setEndDate(req.getEndDate() != null ? parseDate(req.getEndDate(), null) : null);
        template.setMaxOccurrences(req.getMaxOccurrences());
        template.setCustomerId(req.getCustomerId());
        template.setDisplayName(req.getDisplayName());
        template.setPaymentTerms(req.getPaymentTerms());
        template.setDeliveryCharge(safe(req.getDeliveryCharge()));
        template.setOtherCharge(safe(req.getOtherCharge()));
        template.setDepositAmount(safe(req.getDepositAmount()));
        template.setNote(req.getNote());
        template.setInvoiceDiscount(safe(req.getInvoiceDiscount()));
        template.setTaxRate(req.getTaxRate());
        template.setDeliveryRecipientName(req.getDeliveryRecipientName());
        template.setDeliveryPhone(req.getDeliveryPhone());
        template.setDeliveryAddress(req.getDeliveryAddress());
    }

    private RecurringInvoiceDtos.TemplateResponse toResponse(RecurringInvoiceTemplate t) {
        var resp = new RecurringInvoiceDtos.TemplateResponse();
        resp.setId(t.getId());
        resp.setName(t.getName());
        resp.setDescription(t.getDescription());
        resp.setFrequency(t.getFrequency());
        resp.setIntervalCount(t.getIntervalCount());
        resp.setDayOfWeek(t.getDayOfWeek());
        resp.setDayOfMonth(t.getDayOfMonth());
        resp.setMonthOfYear(t.getMonthOfYear());
        resp.setNextRunDate(t.getNextRunDate() != null ? t.getNextRunDate().toString() : null);
        resp.setEndDate(t.getEndDate() != null ? t.getEndDate().toString() : null);
        resp.setMaxOccurrences(t.getMaxOccurrences());
        resp.setOccurrencesCount(t.getOccurrencesCount());
        resp.setCustomerId(t.getCustomerId());
        if (t.getCustomerId() != null) {
            customerRepository.findById(t.getCustomerId()).ifPresent(c ->
                    resp.setCustomerName(c.getDisplayName() != null ? c.getDisplayName() : c.getNameEn()));
        }
        resp.setDisplayName(t.getDisplayName());
        resp.setPaymentTerms(t.getPaymentTerms());
        resp.setDeliveryCharge(t.getDeliveryCharge());
        resp.setOtherCharge(t.getOtherCharge());
        resp.setDepositAmount(t.getDepositAmount());
        resp.setNote(t.getNote());
        resp.setInvoiceDiscount(t.getInvoiceDiscount());
        resp.setTaxRate(t.getTaxRate());
        resp.setDeliveryRecipientName(t.getDeliveryRecipientName());
        resp.setDeliveryPhone(t.getDeliveryPhone());
        resp.setDeliveryAddress(t.getDeliveryAddress());
        resp.setLines(parseLinesSafe(t.getLinesJson()));
        resp.setActive(t.isActive());
        resp.setLastGeneratedAt(t.getLastGeneratedAt() != null ? t.getLastGeneratedAt().toString() : null);
        resp.setLastInvoiceId(t.getLastInvoiceId());
        resp.setCreatedAt(t.getCreatedAt() != null ? t.getCreatedAt().toString() : null);
        return resp;
    }

    private String toJson(List<RecurringInvoiceDtos.RecurringLineItem> lines) {
        try {
            return lines == null ? "[]" : MAPPER.writeValueAsString(lines);
        } catch (Exception e) {
            return "[]";
        }
    }

    private List<RecurringInvoiceDtos.RecurringLineItem> parseLines(String json) {
        try {
            return MAPPER.readValue(json, new TypeReference<List<RecurringInvoiceDtos.RecurringLineItem>>() {});
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    private List<RecurringInvoiceDtos.RecurringLineItem> parseLinesSafe(String json) {
        try {
            return json == null ? Collections.emptyList() : MAPPER.readValue(json, new TypeReference<>() {});
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    private LocalDate parseDate(String value, LocalDate fallback) {
        if (value == null || value.isBlank()) return fallback;
        try {
            return LocalDate.parse(value);
        } catch (Exception e) {
            return fallback;
        }
    }

    private BigDecimal safe(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }
}
