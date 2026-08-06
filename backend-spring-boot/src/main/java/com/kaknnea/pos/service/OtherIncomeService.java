package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.OtherIncome;
import com.kaknnea.pos.domain.OtherIncomeCategory;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.dto.OtherIncomeDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.OtherIncomeCategoryRepository;
import com.kaknnea.pos.repository.OtherIncomeRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.SecurityUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class OtherIncomeService {
    private final OtherIncomeRepository incomeRepository;
    private final OtherIncomeCategoryRepository categoryRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public List<OtherIncomeDtos.CategoryResponse> listCategories() {
        return categoryRepository.findAllByOrderByNameEnAsc().stream().map(this::toCategoryResponse).collect(Collectors.toList());
    }

    @Transactional
    public OtherIncomeDtos.CategoryResponse createCategory(OtherIncomeDtos.CategoryRequest request) {
        OtherIncomeCategory category = new OtherIncomeCategory();
        category.setNameEn(request.getNameEn().trim());
        category.setNameKm(request.getNameKm().trim());
        category.setColor(request.getColor() != null ? request.getColor() : "#16a34a");
        category.setActive(request.isActive());
        return toCategoryResponse(categoryRepository.save(category));
    }

    @Transactional
    public OtherIncomeDtos.CategoryResponse updateCategory(Long id, OtherIncomeDtos.CategoryRequest request) {
        OtherIncomeCategory category = categoryRepository.findById(id).orElseThrow(() -> new ApiException("Income category not found"));
        category.setNameEn(request.getNameEn().trim());
        category.setNameKm(request.getNameKm().trim());
        category.setColor(request.getColor() != null ? request.getColor() : category.getColor());
        category.setActive(request.isActive());
        return toCategoryResponse(categoryRepository.save(category));
    }

    @Transactional
    public void deleteCategory(Long id) {
        OtherIncomeCategory category = categoryRepository.findById(id).orElseThrow(() -> new ApiException("Income category not found"));
        category.setActive(false);
        categoryRepository.save(category);
    }

    @Transactional(readOnly = true)
    public List<OtherIncomeDtos.IncomeResponse> list(String from, String to, Long categoryId, String status) {
        Sort sort = Sort.by(Sort.Direction.DESC, "incomeDate", "id");
        List<OtherIncome> incomes;
        if (from != null && to != null) {
            LocalDate fromDate = LocalDate.parse(from);
            LocalDate toDate = LocalDate.parse(to);
            incomes = status != null && !status.isBlank()
                    ? incomeRepository.findAllByActiveTrueAndIncomeDateBetweenAndStatus(fromDate, toDate, status, sort)
                    : incomeRepository.findAllByActiveTrueAndIncomeDateBetween(fromDate, toDate, sort);
        } else if (categoryId != null) {
            incomes = incomeRepository.findAllByActiveTrueAndCategoryId(categoryId, sort);
        } else if (status != null && !status.isBlank()) {
            incomes = incomeRepository.findAllByActiveTrueAndStatus(status, sort);
        } else {
            incomes = incomeRepository.findAllByActiveTrue(sort);
        }
        return incomes.stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional
    public OtherIncomeDtos.IncomeResponse create(OtherIncomeDtos.IncomeRequest request) {
        User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow();
        OtherIncomeCategory category = categoryRepository.findById(request.getCategoryId()).orElseThrow(() -> new ApiException("Income category not found"));
        OtherIncome income = new OtherIncome();
        applyRequest(income, request, category);
        income.setStatus("APPROVED");
        income.setCreatedBy(actor);
        income.setApprovedBy(actor);
        income.setApprovedAt(Instant.now());
        income.setActive(true);
        OtherIncome saved = incomeRepository.save(income);
        saved.setIncomeNumber("OIN-" + String.format("%06d", saved.getId()));
        return toResponse(incomeRepository.save(saved));
    }

    @Transactional
    public OtherIncomeDtos.IncomeResponse update(Long id, OtherIncomeDtos.IncomeRequest request) {
        OtherIncome income = incomeRepository.findById(id).orElseThrow(() -> new ApiException("Other income not found"));
        OtherIncomeCategory category = categoryRepository.findById(request.getCategoryId()).orElseThrow(() -> new ApiException("Income category not found"));
        applyRequest(income, request, category);
        return toResponse(incomeRepository.save(income));
    }

    @Transactional
    public OtherIncomeDtos.IncomeResponse approve(Long id) {
        User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow();
        OtherIncome income = incomeRepository.findById(id).orElseThrow(() -> new ApiException("Other income not found"));
        if ("APPROVED".equals(income.getStatus())) {
            return toResponse(income);
        }
        income.setStatus("APPROVED");
        income.setApprovedBy(actor);
        income.setApprovedAt(Instant.now());
        return toResponse(incomeRepository.save(income));
    }

    @Transactional
    public OtherIncomeDtos.IncomeResponse revertToDraft(Long id) {
        OtherIncome income = incomeRepository.findById(id).orElseThrow(() -> new ApiException("Other income not found"));
        throw new ApiException("Draft income is disabled. Use edit or delete instead.");
    }

    @Transactional
    public void delete(Long id) {
        OtherIncome income = incomeRepository.findById(id).orElseThrow(() -> new ApiException("Other income not found"));
        income.setActive(false);
        incomeRepository.save(income);
    }

    @Transactional(readOnly = true)
    public OtherIncomeDtos.Summary summary() {
        YearMonth thisMonth = YearMonth.now();
        YearMonth lastMonth = thisMonth.minusMonths(1);
        OtherIncomeDtos.Summary summary = new OtherIncomeDtos.Summary();
        summary.setTotalThisMonth(incomeRepository.sumAmountByDateRange(thisMonth.atDay(1), thisMonth.atEndOfMonth()));
        summary.setTotalLastMonth(incomeRepository.sumAmountByDateRange(lastMonth.atDay(1), lastMonth.atEndOfMonth()));
        summary.setCountDraft(0);
        summary.setCountApproved(incomeRepository.countByStatus("APPROVED"));
        summary.setByCategory(categoryRepository.findAllByActiveOrderByNameEnAsc(true).stream().map(category -> {
            OtherIncomeDtos.CategoryBreakdown row = new OtherIncomeDtos.CategoryBreakdown();
            row.setCategoryId(category.getId());
            row.setCategoryNameEn(category.getNameEn());
            row.setCategoryNameKm(category.getNameKm());
            row.setCategoryColor(category.getColor());
            row.setTotal(BigDecimal.ZERO);
            return row;
        }).collect(Collectors.toList()));
        return summary;
    }

    private void applyRequest(OtherIncome income, OtherIncomeDtos.IncomeRequest request, OtherIncomeCategory category) {
        income.setIncomeDate(LocalDate.parse(request.getIncomeDate()));
        income.setCategory(category);
        income.setPayerName(request.getPayerName());
        income.setDescription(request.getDescription().trim());
        income.setAmount(request.getAmount());
        income.setPaymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : "CASH");
        income.setReference(request.getReference());
        income.setNote(request.getNote());
    }

    private OtherIncomeDtos.CategoryResponse toCategoryResponse(OtherIncomeCategory category) {
        OtherIncomeDtos.CategoryResponse response = new OtherIncomeDtos.CategoryResponse();
        response.setId(category.getId());
        response.setNameEn(category.getNameEn());
        response.setNameKm(category.getNameKm());
        response.setColor(category.getColor());
        response.setActive(category.isActive());
        return response;
    }

    private OtherIncomeDtos.IncomeResponse toResponse(OtherIncome income) {
        OtherIncomeDtos.IncomeResponse response = new OtherIncomeDtos.IncomeResponse();
        response.setId(income.getId());
        response.setIncomeNumber(income.getIncomeNumber());
        response.setIncomeDate(income.getIncomeDate() != null ? income.getIncomeDate().toString() : null);
        response.setCategoryId(income.getCategory() != null ? income.getCategory().getId() : null);
        response.setCategoryNameEn(income.getCategory() != null ? income.getCategory().getNameEn() : null);
        response.setCategoryNameKm(income.getCategory() != null ? income.getCategory().getNameKm() : null);
        response.setCategoryColor(income.getCategory() != null ? income.getCategory().getColor() : null);
        response.setPayerName(income.getPayerName());
        response.setDescription(income.getDescription());
        response.setAmount(income.getAmount());
        response.setPaymentMethod(income.getPaymentMethod());
        response.setReference(income.getReference());
        response.setNote(income.getNote());
        response.setStatus(income.getStatus());
        response.setCreatedByName(income.getCreatedBy() != null ? income.getCreatedBy().getFullName() : null);
        response.setApprovedByName(income.getApprovedBy() != null ? income.getApprovedBy().getFullName() : null);
        response.setApprovedAt(income.getApprovedAt() != null ? income.getApprovedAt().toString() : null);
        response.setCreatedAt(income.getCreatedAt() != null ? income.getCreatedAt().toString() : null);
        return response;
    }
}
