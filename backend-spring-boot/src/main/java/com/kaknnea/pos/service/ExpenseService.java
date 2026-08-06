package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Expense;
import com.kaknnea.pos.domain.ExpenseCategory;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.dto.ExpenseDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.ExpenseCategoryRepository;
import com.kaknnea.pos.repository.ExpenseRepository;
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
public class ExpenseService {

    private final ExpenseRepository expenseRepository;
    private final ExpenseCategoryRepository categoryRepository;
    private final UserRepository userRepository;

    // ── Categories ────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ExpenseDtos.ExpenseCategoryResponse> listCategories() {
        return categoryRepository.findAllByOrderByNameEnAsc()
                .stream().map(this::toCategoryResponse).collect(Collectors.toList());
    }

    @Transactional
    public ExpenseDtos.ExpenseCategoryResponse createCategory(ExpenseDtos.ExpenseCategoryRequest request) {
        ExpenseCategory cat = new ExpenseCategory();
        cat.setNameEn(request.getNameEn().trim());
        cat.setNameKm(request.getNameKm().trim());
        cat.setColor(request.getColor() != null ? request.getColor() : "#6366f1");
        cat.setActive(request.isActive());
        return toCategoryResponse(categoryRepository.save(cat));
    }

    @Transactional
    public ExpenseDtos.ExpenseCategoryResponse updateCategory(Long id, ExpenseDtos.ExpenseCategoryRequest request) {
        ExpenseCategory cat = categoryRepository.findById(id)
                .orElseThrow(() -> new ApiException("Category not found"));
        cat.setNameEn(request.getNameEn().trim());
        cat.setNameKm(request.getNameKm().trim());
        cat.setColor(request.getColor() != null ? request.getColor() : cat.getColor());
        cat.setActive(request.isActive());
        return toCategoryResponse(categoryRepository.save(cat));
    }

    @Transactional
    public void deleteCategory(Long id) {
        ExpenseCategory cat = categoryRepository.findById(id)
                .orElseThrow(() -> new ApiException("Category not found"));
        cat.setActive(false);
        categoryRepository.save(cat);
    }

    // ── Expenses ──────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ExpenseDtos.ExpenseResponse> list(String from, String to, Long categoryId, String status) {
        Sort sort = Sort.by(Sort.Direction.DESC, "expenseDate", "id");

        List<Expense> expenses;
        if (from != null && to != null) {
            LocalDate fromDate = LocalDate.parse(from);
            LocalDate toDate = LocalDate.parse(to);
            if (status != null && !status.isBlank()) {
                expenses = expenseRepository.findAllByActiveTrueAndExpenseDateBetweenAndStatus(fromDate, toDate, status, sort);
            } else {
                expenses = expenseRepository.findAllByActiveTrueAndExpenseDateBetween(fromDate, toDate, sort);
            }
        } else if (categoryId != null) {
            expenses = expenseRepository.findAllByActiveTrueAndCategoryId(categoryId, sort);
        } else if (status != null && !status.isBlank()) {
            expenses = expenseRepository.findAllByActiveTrueAndStatus(status, sort);
        } else {
            expenses = expenseRepository.findAllByActiveTrue(sort);
        }

        return expenses.stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional
    public ExpenseDtos.ExpenseResponse create(ExpenseDtos.ExpenseRequest request) {
        User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow();
        ExpenseCategory category = categoryRepository.findById(request.getCategoryId())
                .orElseThrow(() -> new ApiException("Expense category not found"));

        Expense expense = new Expense();
        expense.setExpenseDate(LocalDate.parse(request.getExpenseDate()));
        expense.setCategory(category);
        expense.setDescription(request.getDescription().trim());
        expense.setAmount(request.getAmount());
        expense.setPaymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : "CASH");
        expense.setReference(request.getReference());
        expense.setNote(request.getNote());
        expense.setStatus("APPROVED");
        expense.setCreatedBy(actor);
        expense.setApprovedBy(actor);
        expense.setApprovedAt(Instant.now());
        expense.setActive(true);

        Expense saved = expenseRepository.save(expense);
        // Generate expense number after save
        saved.setExpenseNumber("EXP-" + String.format("%06d", saved.getId()));
        return toResponse(expenseRepository.save(saved));
    }

    @Transactional
    public ExpenseDtos.ExpenseResponse update(Long id, ExpenseDtos.ExpenseRequest request) {
        Expense expense = expenseRepository.findById(id)
                .orElseThrow(() -> new ApiException("Expense not found"));
        ExpenseCategory category = categoryRepository.findById(request.getCategoryId())
                .orElseThrow(() -> new ApiException("Expense category not found"));

        expense.setExpenseDate(LocalDate.parse(request.getExpenseDate()));
        expense.setCategory(category);
        expense.setDescription(request.getDescription().trim());
        expense.setAmount(request.getAmount());
        expense.setPaymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : "CASH");
        expense.setReference(request.getReference());
        expense.setNote(request.getNote());
        return toResponse(expenseRepository.save(expense));
    }

    @Transactional
    public ExpenseDtos.ExpenseResponse approve(Long id) {
        User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow();
        Expense expense = expenseRepository.findById(id)
                .orElseThrow(() -> new ApiException("Expense not found"));
        if ("APPROVED".equals(expense.getStatus())) {
            return toResponse(expense);
        }
        expense.setStatus("APPROVED");
        expense.setApprovedBy(actor);
        expense.setApprovedAt(Instant.now());
        return toResponse(expenseRepository.save(expense));
    }

    @Transactional
    public ExpenseDtos.ExpenseResponse revertToDraft(Long id) {
        Expense expense = expenseRepository.findById(id)
                .orElseThrow(() -> new ApiException("Expense not found"));
        throw new ApiException("Draft expenses are disabled. Use edit or delete instead.");
    }

    @Transactional
    public void delete(Long id) {
        Expense expense = expenseRepository.findById(id)
                .orElseThrow(() -> new ApiException("Expense not found"));
        expense.setActive(false);
        expenseRepository.save(expense);
    }

    @Transactional(readOnly = true)
    public ExpenseDtos.ExpenseSummary summary() {
        YearMonth thisMonth = YearMonth.now();
        YearMonth lastMonth = thisMonth.minusMonths(1);

        BigDecimal totalThisMonth = expenseRepository.sumAmountByDateRange(
                thisMonth.atDay(1), thisMonth.atEndOfMonth());
        BigDecimal totalLastMonth = expenseRepository.sumAmountByDateRange(
                lastMonth.atDay(1), lastMonth.atEndOfMonth());

        long countDraft = 0;
        long countApproved = expenseRepository.countByStatus("APPROVED");

        List<ExpenseDtos.CategoryBreakdown> byCategory = categoryRepository.findAllByActiveOrderByNameEnAsc(true)
                .stream().map(cat -> {
                    ExpenseDtos.CategoryBreakdown bd = new ExpenseDtos.CategoryBreakdown();
                    bd.setCategoryId(cat.getId());
                    bd.setCategoryNameEn(cat.getNameEn());
                    bd.setCategoryNameKm(cat.getNameKm());
                    bd.setCategoryColor(cat.getColor());
                    bd.setTotal(BigDecimal.ZERO); // category-level breakdown requires a custom query — placeholder
                    return bd;
                }).collect(Collectors.toList());

        ExpenseDtos.ExpenseSummary summary = new ExpenseDtos.ExpenseSummary();
        summary.setTotalThisMonth(totalThisMonth);
        summary.setTotalLastMonth(totalLastMonth);
        summary.setCountDraft(countDraft);
        summary.setCountApproved(countApproved);
        summary.setByCategory(byCategory);
        return summary;
    }

    // ── Mappers ───────────────────────────────────────────────────────────────

    private ExpenseDtos.ExpenseCategoryResponse toCategoryResponse(ExpenseCategory cat) {
        ExpenseDtos.ExpenseCategoryResponse r = new ExpenseDtos.ExpenseCategoryResponse();
        r.setId(cat.getId());
        r.setNameEn(cat.getNameEn());
        r.setNameKm(cat.getNameKm());
        r.setColor(cat.getColor());
        r.setActive(cat.isActive());
        return r;
    }

    private ExpenseDtos.ExpenseResponse toResponse(Expense e) {
        ExpenseDtos.ExpenseResponse r = new ExpenseDtos.ExpenseResponse();
        r.setId(e.getId());
        r.setExpenseNumber(e.getExpenseNumber());
        r.setExpenseDate(e.getExpenseDate() != null ? e.getExpenseDate().toString() : null);
        r.setCategoryId(e.getCategory() != null ? e.getCategory().getId() : null);
        r.setCategoryNameEn(e.getCategory() != null ? e.getCategory().getNameEn() : null);
        r.setCategoryNameKm(e.getCategory() != null ? e.getCategory().getNameKm() : null);
        r.setCategoryColor(e.getCategory() != null ? e.getCategory().getColor() : null);
        r.setDescription(e.getDescription());
        r.setAmount(e.getAmount());
        r.setPaymentMethod(e.getPaymentMethod());
        r.setReference(e.getReference());
        r.setNote(e.getNote());
        r.setStatus(e.getStatus());
        r.setCreatedByName(e.getCreatedBy() != null ? e.getCreatedBy().getFullName() : null);
        r.setApprovedByName(e.getApprovedBy() != null ? e.getApprovedBy().getFullName() : null);
        r.setApprovedAt(e.getApprovedAt() != null ? e.getApprovedAt().toString() : null);
        r.setCreatedAt(e.getCreatedAt() != null ? e.getCreatedAt().toString() : null);
        return r;
    }
}
