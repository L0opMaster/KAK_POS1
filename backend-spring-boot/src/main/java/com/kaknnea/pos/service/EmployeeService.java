package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.dto.EmployeeDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.*;
import com.kaknnea.pos.util.SecurityUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class EmployeeService {
    private final EmployeeRepository employeeRepository;
    private final EmployeeExpenseRepository expenseRepository;
    private final EmployeeAdvanceRepository advanceRepository;
    private final EmployeeAdvancePaymentRepository advancePaymentRepository;
    private final PayrollRunRepository payrollRunRepository;
    private final PayrollLineRepository payrollLineRepository;
    private final UserRepository userRepository;
    private final SystemSettingRepository systemSettingRepository;

    @Transactional(readOnly = true)
    public List<EmployeeDtos.EmployeeResponse> listEmployees(String q, String status, String department) {
        List<Employee> rows = status != null && !status.isBlank()
                ? employeeRepository.findAllByActiveTrueAndStatus(status.toUpperCase(Locale.ROOT), Sort.by("fullName"))
                : employeeRepository.findAllByActiveTrue(Sort.by("fullName"));
        String needle = q == null ? "" : q.trim().toLowerCase(Locale.ROOT);
        String dept = department == null ? "" : department.trim().toLowerCase(Locale.ROOT);
        return rows.stream()
                .filter(e -> needle.isBlank()
                        || safe(e.getFullName()).toLowerCase(Locale.ROOT).contains(needle)
                        || safe(e.getPhone()).toLowerCase(Locale.ROOT).contains(needle)
                        || safe(e.getEmployeeCode()).toLowerCase(Locale.ROOT).contains(needle))
                .filter(e -> dept.isBlank() || safe(e.getDepartment()).toLowerCase(Locale.ROOT).equals(dept))
                .map(this::toEmployeeResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public EmployeeDtos.EmployeeResponse getEmployee(Long id) {
        return toEmployeeResponse(findEmployee(id));
    }

    @Transactional(readOnly = true)
    public EmployeeDtos.EmployeeProfileResponse profile(Long id) {
        Employee employee = findEmployee(id);
        EmployeeDtos.EmployeeProfileResponse response = new EmployeeDtos.EmployeeProfileResponse();
        response.setEmployee(toEmployeeResponse(employee));
        response.setOpenAdvanceBalance(openAdvanceBalance(id));
        response.setUnpaidExpenseTotal(unpaidExpenseTotal(id));
        response.setCurrentMonthPayroll(currentMonthPayroll(id));
        response.setExpenses(expenseRepository.findAllByActiveTrueAndEmployeeId(id, Sort.by(Sort.Direction.DESC, "expenseDate", "id"))
                .stream().map(this::toExpenseResponse).collect(Collectors.toList()));
        response.setAdvances(advanceRepository.findAllByActiveTrueAndEmployeeId(id, Sort.by(Sort.Direction.DESC, "advanceDate", "id"))
                .stream().map(this::toAdvanceResponse).collect(Collectors.toList()));
        response.setPayrollLines(payrollLineRepository.findAllByEmployeeIdOrderByPayrollRunPayDateDesc(id)
                .stream().map(this::toPayrollLineResponse).collect(Collectors.toList()));
        return response;
    }

    @Transactional
    public EmployeeDtos.EmployeeResponse createEmployee(EmployeeDtos.EmployeeRequest request) {
        Employee employee = new Employee();
        applyEmployee(employee, request);
        Employee saved = employeeRepository.save(employee);
        if (saved.getEmployeeCode() == null || saved.getEmployeeCode().isBlank()) {
            saved.setEmployeeCode("EMP-" + String.format("%05d", saved.getId()));
        }
        return toEmployeeResponse(employeeRepository.save(saved));
    }

    @Transactional
    public EmployeeDtos.EmployeeResponse updateEmployee(Long id, EmployeeDtos.EmployeeRequest request) {
        Employee employee = findEmployee(id);
        applyEmployee(employee, request);
        return toEmployeeResponse(employeeRepository.save(employee));
    }

    @Transactional
    public EmployeeDtos.EmployeeResponse setEmployeeStatus(Long id, String status) {
        Employee employee = findEmployee(id);
        employee.setStatus(status == null ? "ACTIVE" : status.toUpperCase(Locale.ROOT));
        return toEmployeeResponse(employeeRepository.save(employee));
    }

    @Transactional
    public void deleteEmployee(Long id) {
        Employee employee = findEmployee(id);
        employee.setActive(false);
        employeeRepository.save(employee);
    }

    @Transactional(readOnly = true)
    public List<EmployeeDtos.EmployeeMasterDataOption> listMasterData(String type) {
        MasterDataKind kind = resolveMasterDataKind(type);
        Map<String, EmployeeDtos.EmployeeMasterDataOption> options = new LinkedHashMap<>();
        for (SystemSetting setting : systemSettingRepository.findAllByKeyStartingWithOrderByValueAsc(kind.keyPrefix)) {
            addMasterOption(options, setting.getValue(), "MASTER");
        }
        List<String> employeeValues = kind == MasterDataKind.POSITION
                ? employeeRepository.findDistinctActivePositions()
                : employeeRepository.findDistinctActiveDepartments();
        for (String value : employeeValues) {
            addMasterOption(options, value, "EMPLOYEE");
        }
        return new ArrayList<>(options.values());
    }

    @Transactional
    public EmployeeDtos.EmployeeMasterDataOption addMasterData(String type, EmployeeDtos.EmployeeMasterDataRequest request) {
        MasterDataKind kind = resolveMasterDataKind(type);
        String value = normalizeMasterValue(request.getValue());
        if (value.isBlank()) {
            throw new ApiException(kind.label + " is required");
        }
        String key = kind.keyPrefix + masterKeySuffix(value);
        SystemSetting setting = systemSettingRepository.findByKey(key).orElseGet(() -> {
            SystemSetting created = new SystemSetting();
            created.setKey(key);
            return created;
        });
        setting.setValue(value);
        systemSettingRepository.save(setting);
        return toMasterOption(value, "MASTER");
    }

    @Transactional(readOnly = true)
    public List<EmployeeDtos.EmployeeExpenseResponse> listExpenses(Long employeeId, String status) {
        Sort sort = Sort.by(Sort.Direction.DESC, "expenseDate", "id");
        List<EmployeeExpense> rows = employeeId != null
                ? expenseRepository.findAllByActiveTrueAndEmployeeId(employeeId, sort)
                : status != null && !status.isBlank()
                    ? expenseRepository.findAllByActiveTrueAndStatus(status.toUpperCase(Locale.ROOT), sort)
                    : expenseRepository.findAllByActiveTrue(sort);
        return rows.stream().map(this::toExpenseResponse).collect(Collectors.toList());
    }

    @Transactional
    public EmployeeDtos.EmployeeExpenseResponse createExpense(EmployeeDtos.EmployeeExpenseRequest request) {
        EmployeeExpense row = new EmployeeExpense();
        row.setEmployee(findEmployee(request.getEmployeeId()));
        row.setExpenseDate(LocalDate.parse(request.getExpenseDate()));
        row.setDescription(request.getDescription().trim());
        row.setAmount(safe(request.getAmount()));
        row.setPaymentMethod(defaultText(request.getPaymentMethod(), "CASH"));
        row.setReference(request.getReference());
        row.setNote(request.getNote());
        row.setCreatedBy(currentUser());
        return toExpenseResponse(expenseRepository.save(row));
    }

    @Transactional
    public EmployeeDtos.EmployeeExpenseResponse approveExpense(Long id) {
        EmployeeExpense row = findExpense(id);
        row.setStatus("APPROVED");
        row.setApprovedBy(currentUser());
        row.setApprovedAt(Instant.now());
        return toExpenseResponse(expenseRepository.save(row));
    }

    @Transactional
    public EmployeeDtos.EmployeeExpenseResponse markExpensePaid(Long id) {
        EmployeeExpense row = findExpense(id);
        if ("DRAFT".equalsIgnoreCase(row.getStatus())) {
            row.setStatus("APPROVED");
            row.setApprovedBy(currentUser());
            row.setApprovedAt(Instant.now());
        }
        row.setStatus("PAID");
        row.setPaidAt(Instant.now());
        return toExpenseResponse(expenseRepository.save(row));
    }

    @Transactional(readOnly = true)
    public List<EmployeeDtos.EmployeeAdvanceResponse> listAdvances(Long employeeId, String status) {
        Sort sort = Sort.by(Sort.Direction.DESC, "advanceDate", "id");
        List<EmployeeAdvance> rows = employeeId != null
                ? advanceRepository.findAllByActiveTrueAndEmployeeId(employeeId, sort)
                : status != null && !status.isBlank()
                    ? advanceRepository.findAllByActiveTrueAndStatus(status.toUpperCase(Locale.ROOT), sort)
                    : advanceRepository.findAllByActiveTrue(sort);
        return rows.stream().map(this::toAdvanceResponse).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public EmployeeDtos.EmployeeAdvanceResponse getAdvance(Long id) {
        return toAdvanceResponse(findAdvance(id));
    }

    @Transactional
    public EmployeeDtos.EmployeeAdvanceResponse createAdvance(EmployeeDtos.EmployeeAdvanceRequest request) {
        EmployeeAdvance row = new EmployeeAdvance();
        row.setEmployee(findEmployee(request.getEmployeeId()));
        row.setAdvanceDate(LocalDate.parse(request.getAdvanceDate()));
        row.setType(defaultText(request.getType(), "ADVANCE").toUpperCase(Locale.ROOT));
        row.setAmount(safe(request.getAmount()));
        row.setRemainingBalance(safe(request.getAmount()));
        row.setRepaymentMethod(defaultText(request.getRepaymentMethod(), "PAYROLL_DEDUCTION").toUpperCase(Locale.ROOT));
        applyInstallmentPlan(row, request);
        row.setNote(request.getNote());
        row.setCreatedBy(currentUser());
        return toAdvanceResponse(advanceRepository.save(row));
    }

    @Transactional
    public EmployeeDtos.EmployeeAdvanceResponse updateAdvance(Long id, EmployeeDtos.EmployeeAdvanceRequest request) {
        EmployeeAdvance row = findAdvance(id);
        BigDecimal paidAmount = safe(row.getAmount()).subtract(safe(row.getRemainingBalance()));
        BigDecimal requestedAmount = safe(request.getAmount());
        if (requestedAmount.compareTo(paidAmount) < 0) {
            throw new ApiException("Advance amount cannot be less than amount already repaid");
        }
        row.setEmployee(findEmployee(request.getEmployeeId()));
        row.setAdvanceDate(LocalDate.parse(request.getAdvanceDate()));
        row.setType(defaultText(request.getType(), "ADVANCE").toUpperCase(Locale.ROOT));
        row.setAmount(requestedAmount);
        row.setRemainingBalance(requestedAmount.subtract(paidAmount));
        row.setRepaymentMethod(defaultText(request.getRepaymentMethod(), "PAYROLL_DEDUCTION").toUpperCase(Locale.ROOT));
        applyInstallmentPlan(row, request);
        row.setNote(request.getNote());
        row.setStatus(row.getRemainingBalance().compareTo(BigDecimal.ZERO) <= 0 ? "PAID" : "OPEN");
        return toAdvanceResponse(advanceRepository.save(row));
    }

    @Transactional
    public EmployeeDtos.EmployeeAdvanceResponse payAdvance(Long id, EmployeeDtos.EmployeeAdvancePaymentRequest request) {
        EmployeeAdvance advance = findAdvance(id);
        BigDecimal requested = safe(request.getAmount());
        if (requested.compareTo(safe(advance.getRemainingBalance())) > 0) {
            throw new ApiException("Payment amount cannot exceed remaining balance");
        }
        applyAdvancePayment(advance, LocalDate.parse(request.getPaymentDate()), requested, "MANUAL", request.getReference());
        return toAdvanceResponse(advanceRepository.save(advance));
    }

    @Transactional
    public EmployeeDtos.EmployeeAdvanceResponse cancelAdvance(Long id) {
        EmployeeAdvance advance = findAdvance(id);
        if (advance.getRemainingBalance().compareTo(advance.getAmount()) != 0) {
            throw new ApiException("Cannot cancel an advance with repayments");
        }
        advance.setStatus("CANCELLED");
        advance.setActive(false);
        return toAdvanceResponse(advanceRepository.save(advance));
    }

    @Transactional(readOnly = true)
    public List<EmployeeDtos.PayrollRunResponse> listPayrollRuns() {
        return payrollRunRepository.findAllByActiveTrue(Sort.by(Sort.Direction.DESC, "payDate", "id"))
                .stream().map(this::toPayrollRunResponse).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public EmployeeDtos.PayrollRunResponse getPayrollRun(Long id) {
        return toPayrollRunResponse(findPayrollRun(id));
    }

    @Transactional
    public EmployeeDtos.PayrollRunResponse createPayrollRun(EmployeeDtos.PayrollRunRequest request) {
        LocalDate periodStart = LocalDate.parse(request.getPeriodStart());
        LocalDate periodEnd = LocalDate.parse(request.getPeriodEnd());
        LocalDate payDate = LocalDate.parse(request.getPayDate());
        if (periodEnd.isBefore(periodStart)) {
            throw new ApiException("Payroll period end cannot be before period start");
        }
        PayrollRun run = new PayrollRun();
        run.setPeriodStart(periodStart);
        run.setPeriodEnd(periodEnd);
        run.setPayDate(payDate);
        run.setNote(request.getNote());
        run.setCreatedBy(currentUser());
        return toPayrollRunResponse(payrollRunRepository.save(run));
    }

    @Transactional
    public EmployeeDtos.PayrollRunResponse generatePayrollLines(Long id) {
        PayrollRun run = findPayrollRun(id);
        if (!"DRAFT".equalsIgnoreCase(run.getStatus())) {
            throw new ApiException("Only draft payroll can be regenerated");
        }
        payrollLineRepository.deleteAllByPayrollRunId(run.getId());
        payrollLineRepository.flush();
        run.getLines().clear();
        for (Employee employee : employeeRepository.findAllByActiveTrueAndStatus("ACTIVE", Sort.by("fullName"))) {
            PayrollLine line = new PayrollLine();
            line.setPayrollRun(run);
            line.setEmployee(employee);
            line.setBasePay(safe(employee.getBaseSalary()));
            line.setBonus(BigDecimal.ZERO);
            line.setDeductions(BigDecimal.ZERO);
            line.setAdvanceDeduction(scheduledPayrollAdvanceDeduction(employee.getId()));
            recalcLine(line);
            run.getLines().add(line);
        }
        recalcRun(run);
        return toPayrollRunResponse(payrollRunRepository.save(run));
    }

    @Transactional
    public EmployeeDtos.PayrollRunResponse updatePayrollLine(Long runId, Long lineId, EmployeeDtos.PayrollLineUpdateRequest request) {
        PayrollRun run = findPayrollRun(runId);
        if (!"DRAFT".equalsIgnoreCase(run.getStatus())) {
            throw new ApiException("Only draft payroll lines can be edited");
        }
        PayrollLine line = run.getLines().stream()
                .filter(l -> l.getId().equals(lineId))
                .findFirst()
                .orElseThrow(() -> new ApiException("Payroll line not found"));
        line.setBasePay(safe(request.getBasePay()));
        line.setBonus(safe(request.getBonus()));
        line.setDeductions(safe(request.getDeductions()));
        line.setAdvanceDeduction(safe(request.getAdvanceDeduction()));
        line.setNote(request.getNote());
        recalcLine(line);
        recalcRun(run);
        return toPayrollRunResponse(payrollRunRepository.save(run));
    }

    @Transactional
    public EmployeeDtos.PayrollRunResponse approvePayrollRun(Long id) {
        PayrollRun run = findPayrollRun(id);
        if ("PAID".equalsIgnoreCase(run.getStatus())) {
            throw new ApiException("Paid payroll cannot be approved again");
        }
        recalcRun(run);
        run.setStatus("APPROVED");
        run.setApprovedBy(currentUser());
        run.setApprovedAt(Instant.now());
        return toPayrollRunResponse(payrollRunRepository.save(run));
    }

    @Transactional
    public EmployeeDtos.PayrollRunResponse markPayrollPaid(Long id) {
        PayrollRun run = findPayrollRun(id);
        if ("PAID".equalsIgnoreCase(run.getStatus())) {
            return toPayrollRunResponse(run);
        }
        if ("DRAFT".equalsIgnoreCase(run.getStatus())) {
            approvePayrollRun(id);
            run = findPayrollRun(id);
        }
        for (PayrollLine line : run.getLines()) {
            BigDecimal deduction = safe(line.getAdvanceDeduction());
            if (deduction.compareTo(BigDecimal.ZERO) > 0) {
                repayOpenAdvances(line.getEmployee().getId(), deduction, run.getPayDate(), "Payroll #" + run.getId());
            }
        }
        run.setStatus("PAID");
        run.setPaidAt(Instant.now());
        return toPayrollRunResponse(payrollRunRepository.save(run));
    }

    public void deletePayrollRun(Long id) {
        PayrollRun run = payrollRunRepository.findById(id).orElseThrow(() -> new ApiException("Payroll run not found"));
        if (!"DRAFT".equals(run.getStatus())) {
            throw new ApiException("Only draft payroll runs can be deleted");
        }
        payrollRunRepository.delete(run);
    }

    private void applyEmployee(Employee employee, EmployeeDtos.EmployeeRequest request) {
        employee.setEmployeeCode(blankToNull(request.getEmployeeCode()));
        employee.setFullName(request.getFullName().trim());
        employee.setPhone(blankToNull(request.getPhone()));
        employee.setEmail(blankToNull(request.getEmail()));
        employee.setPosition(blankToNull(normalizeMasterValue(request.getPosition())));
        employee.setDepartment(blankToNull(normalizeMasterValue(request.getDepartment())));
        employee.setHireDate(request.getHireDate() != null && !request.getHireDate().isBlank() ? LocalDate.parse(request.getHireDate()) : null);
        employee.setBaseSalary(safe(request.getBaseSalary()));
        employee.setPayType(defaultText(request.getPayType(), "MONTHLY").toUpperCase(Locale.ROOT));
        employee.setStatus(defaultText(request.getStatus(), "ACTIVE").toUpperCase(Locale.ROOT));
        employee.setLinkedUser(request.getLinkedUserId() != null ? userRepository.findById(request.getLinkedUserId()).orElseThrow(() -> new ApiException("User not found")) : null);
        employee.setNotes(request.getNotes());
        employee.setActive(true);
    }

    private void addMasterOption(Map<String, EmployeeDtos.EmployeeMasterDataOption> options, String value, String source) {
        String normalized = normalizeMasterValue(value);
        if (normalized.isBlank()) {
            return;
        }
        options.putIfAbsent(normalized.toLowerCase(Locale.ROOT), toMasterOption(normalized, source));
    }

    private EmployeeDtos.EmployeeMasterDataOption toMasterOption(String value, String source) {
        EmployeeDtos.EmployeeMasterDataOption option = new EmployeeDtos.EmployeeMasterDataOption();
        option.setValue(value);
        option.setLabel(value);
        option.setSource(source);
        return option;
    }

    private String normalizeMasterValue(String value) {
        return value == null ? "" : value.trim().replaceAll("\\s+", " ");
    }

    private String masterKeySuffix(String value) {
        String slug = value.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", "-").replaceAll("(^-|-$)", "");
        if (slug.isBlank()) {
            slug = "item";
        }
        if (slug.length() > 42) {
            slug = slug.substring(0, 42).replaceAll("-$", "");
        }
        return slug + "-" + Integer.toHexString(value.toLowerCase(Locale.ROOT).hashCode());
    }

    private MasterDataKind resolveMasterDataKind(String type) {
        String normalized = type == null ? "" : type.trim().toLowerCase(Locale.ROOT);
        return switch (normalized) {
            case "position", "positions" -> MasterDataKind.POSITION;
            case "department", "departments" -> MasterDataKind.DEPARTMENT;
            default -> throw new ApiException("Unsupported employee master data type");
        };
    }

    private enum MasterDataKind {
        POSITION("employee.position.", "Position"),
        DEPARTMENT("employee.department.", "Department");

        private final String keyPrefix;
        private final String label;

        MasterDataKind(String keyPrefix, String label) {
            this.keyPrefix = keyPrefix;
            this.label = label;
        }
    }

    private void recalcLine(PayrollLine line) {
        line.setNetPay(safe(line.getBasePay()).add(safe(line.getBonus())).subtract(safe(line.getDeductions())).subtract(safe(line.getAdvanceDeduction())));
    }

    private void recalcRun(PayrollRun run) {
        BigDecimal gross = BigDecimal.ZERO;
        BigDecimal deductions = BigDecimal.ZERO;
        BigDecimal net = BigDecimal.ZERO;
        for (PayrollLine line : run.getLines()) {
            recalcLine(line);
            gross = gross.add(safe(line.getBasePay())).add(safe(line.getBonus()));
            deductions = deductions.add(safe(line.getDeductions())).add(safe(line.getAdvanceDeduction()));
            net = net.add(safe(line.getNetPay()));
        }
        run.setTotalGross(gross);
        run.setTotalDeductions(deductions);
        run.setTotalNet(net);
    }

    private void repayOpenAdvances(Long employeeId, BigDecimal amount, LocalDate date, String reference) {
        BigDecimal remaining = amount;
        for (EmployeeAdvance advance : advanceRepository.findAllByActiveTrueAndEmployeeId(employeeId, Sort.by("advanceDate", "id"))) {
            if (remaining.compareTo(BigDecimal.ZERO) <= 0) break;
            if (!"OPEN".equalsIgnoreCase(advance.getStatus())) continue;
            BigDecimal applied = remaining.min(safe(advance.getRemainingBalance()));
            applyAdvancePayment(advance, date, applied, "PAYROLL", reference);
            advanceRepository.save(advance);
            remaining = remaining.subtract(applied);
        }
    }

    private BigDecimal scheduledPayrollAdvanceDeduction(Long employeeId) {
        BigDecimal total = BigDecimal.ZERO;
        for (EmployeeAdvance advance : advanceRepository.findAllByActiveTrueAndEmployeeId(employeeId, Sort.by("advanceDate", "id"))) {
            if (!"OPEN".equalsIgnoreCase(advance.getStatus())) continue;
            if (!"PAYROLL_DEDUCTION".equalsIgnoreCase(advance.getRepaymentMethod())) continue;
            BigDecimal installment = safe(advance.getInstallmentAmount());
            if (installment.compareTo(BigDecimal.ZERO) <= 0) continue;
            total = total.add(installment.min(safe(advance.getRemainingBalance())));
        }
        return total;
    }

    private void applyInstallmentPlan(EmployeeAdvance row, EmployeeDtos.EmployeeAdvanceRequest request) {
        if (!"PAYROLL_DEDUCTION".equalsIgnoreCase(row.getRepaymentMethod())) {
            row.setInstallmentCount(null);
            row.setInstallmentAmount(null);
            return;
        }
        BigDecimal amount = safe(request.getAmount());
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            row.setInstallmentCount(null);
            row.setInstallmentAmount(null);
            return;
        }
        Integer count = request.getInstallmentCount();
        BigDecimal requestedInstallment = safe(request.getInstallmentAmount());
        if (requestedInstallment.compareTo(BigDecimal.ZERO) > 0) {
            row.setInstallmentAmount(requestedInstallment);
            row.setInstallmentCount(count != null && count > 0
                    ? count
                    : amount.divide(requestedInstallment, 0, RoundingMode.CEILING).intValue());
        } else if (count != null && count > 0) {
            row.setInstallmentCount(count);
            row.setInstallmentAmount(amount.divide(BigDecimal.valueOf(count), 2, RoundingMode.HALF_UP));
        } else if (row.getInstallmentCount() != null) {
            row.setInstallmentAmount(amount.divide(BigDecimal.valueOf(row.getInstallmentCount()), 2, RoundingMode.HALF_UP));
        } else {
            row.setInstallmentAmount(null);
            row.setInstallmentCount(null);
        }
    }

    private void applyAdvancePayment(EmployeeAdvance advance, LocalDate date, BigDecimal amount, String source, String reference) {
        if (!"OPEN".equalsIgnoreCase(advance.getStatus())) {
            throw new ApiException("Advance is not open");
        }
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException("Payment amount must be greater than zero");
        }
        BigDecimal applied = amount.min(safe(advance.getRemainingBalance()));
        EmployeeAdvancePayment payment = new EmployeeAdvancePayment();
        payment.setAdvance(advance);
        payment.setPaymentDate(date);
        payment.setAmount(applied);
        payment.setSource(source);
        payment.setReference(reference);
        advancePaymentRepository.save(payment);
        advance.setRemainingBalance(safe(advance.getRemainingBalance()).subtract(applied));
        if (advance.getRemainingBalance().compareTo(BigDecimal.ZERO) <= 0) {
            advance.setRemainingBalance(BigDecimal.ZERO);
            advance.setStatus("PAID");
        }
    }

    private Employee findEmployee(Long id) {
        return employeeRepository.findById(id).filter(Employee::isActive).orElseThrow(() -> new ApiException("Employee not found"));
    }

    private EmployeeExpense findExpense(Long id) {
        return expenseRepository.findById(id).filter(EmployeeExpense::isActive).orElseThrow(() -> new ApiException("Employee expense not found"));
    }

    private EmployeeAdvance findAdvance(Long id) {
        return advanceRepository.findById(id).filter(EmployeeAdvance::isActive).orElseThrow(() -> new ApiException("Employee advance not found"));
    }

    private PayrollRun findPayrollRun(Long id) {
        return payrollRunRepository.findById(id).filter(PayrollRun::isActive).orElseThrow(() -> new ApiException("Payroll run not found"));
    }

    private User currentUser() {
        return userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
    }

    private BigDecimal openAdvanceBalance(Long employeeId) {
        return advanceRepository.findAllByActiveTrueAndEmployeeId(employeeId, Sort.by("advanceDate"))
                .stream().filter(a -> "OPEN".equalsIgnoreCase(a.getStatus()))
                .map(a -> safe(a.getRemainingBalance())).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private BigDecimal unpaidExpenseTotal(Long employeeId) {
        return expenseRepository.findAllByActiveTrueAndEmployeeId(employeeId, Sort.by("expenseDate"))
                .stream().filter(e -> !"PAID".equalsIgnoreCase(e.getStatus()))
                .map(e -> safe(e.getAmount())).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private BigDecimal currentMonthPayroll(Long employeeId) {
        YearMonth month = YearMonth.now();
        return payrollLineRepository.findAllByEmployeeIdOrderByPayrollRunPayDateDesc(employeeId).stream()
                .filter(line -> line.getPayrollRun().getPayDate() != null && YearMonth.from(line.getPayrollRun().getPayDate()).equals(month))
                .map(line -> safe(line.getNetPay())).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private EmployeeDtos.EmployeeResponse toEmployeeResponse(Employee e) {
        EmployeeDtos.EmployeeResponse r = new EmployeeDtos.EmployeeResponse();
        r.setId(e.getId());
        r.setEmployeeCode(e.getEmployeeCode());
        r.setFullName(e.getFullName());
        r.setPhone(e.getPhone());
        r.setEmail(e.getEmail());
        r.setPosition(e.getPosition());
        r.setDepartment(e.getDepartment());
        r.setHireDate(e.getHireDate() != null ? e.getHireDate().toString() : null);
        r.setBaseSalary(safe(e.getBaseSalary()));
        r.setPayType(e.getPayType());
        r.setStatus(e.getStatus());
        r.setLinkedUserId(e.getLinkedUser() != null ? e.getLinkedUser().getId() : null);
        r.setLinkedUserName(e.getLinkedUser() != null ? e.getLinkedUser().getFullName() : null);
        r.setNotes(e.getNotes());
        r.setOpenAdvanceBalance(openAdvanceBalance(e.getId()));
        r.setUnpaidExpenseTotal(unpaidExpenseTotal(e.getId()));
        return r;
    }

    private EmployeeDtos.EmployeeExpenseResponse toExpenseResponse(EmployeeExpense e) {
        EmployeeDtos.EmployeeExpenseResponse r = new EmployeeDtos.EmployeeExpenseResponse();
        r.setId(e.getId());
        r.setEmployeeId(e.getEmployee().getId());
        r.setEmployeeName(e.getEmployee().getFullName());
        r.setExpenseDate(e.getExpenseDate() != null ? e.getExpenseDate().toString() : null);
        r.setDescription(e.getDescription());
        r.setAmount(safe(e.getAmount()));
        r.setPaymentMethod(e.getPaymentMethod());
        r.setReference(e.getReference());
        r.setNote(e.getNote());
        r.setStatus(e.getStatus());
        r.setApprovedAt(e.getApprovedAt() != null ? e.getApprovedAt().toString() : null);
        r.setPaidAt(e.getPaidAt() != null ? e.getPaidAt().toString() : null);
        return r;
    }

    private EmployeeDtos.EmployeeAdvanceResponse toAdvanceResponse(EmployeeAdvance a) {
        EmployeeDtos.EmployeeAdvanceResponse r = new EmployeeDtos.EmployeeAdvanceResponse();
        r.setId(a.getId());
        r.setEmployeeId(a.getEmployee().getId());
        r.setEmployeeName(a.getEmployee().getFullName());
        r.setAdvanceDate(a.getAdvanceDate() != null ? a.getAdvanceDate().toString() : null);
        r.setType(a.getType());
        r.setAmount(safe(a.getAmount()));
        r.setRemainingBalance(safe(a.getRemainingBalance()));
        r.setRepaymentMethod(a.getRepaymentMethod());
        r.setInstallmentCount(a.getInstallmentCount());
        r.setInstallmentAmount(safe(a.getInstallmentAmount()));
        r.setStatus(a.getStatus());
        r.setNote(a.getNote());
        return r;
    }

    private EmployeeDtos.PayrollRunResponse toPayrollRunResponse(PayrollRun run) {
        EmployeeDtos.PayrollRunResponse r = new EmployeeDtos.PayrollRunResponse();
        r.setId(run.getId());
        r.setPeriodStart(run.getPeriodStart() != null ? run.getPeriodStart().toString() : null);
        r.setPeriodEnd(run.getPeriodEnd() != null ? run.getPeriodEnd().toString() : null);
        r.setPayDate(run.getPayDate() != null ? run.getPayDate().toString() : null);
        r.setStatus(run.getStatus());
        r.setTotalGross(safe(run.getTotalGross()));
        r.setTotalDeductions(safe(run.getTotalDeductions()));
        r.setTotalNet(safe(run.getTotalNet()));
        r.setNote(run.getNote());
        r.setLines(run.getLines().stream().map(this::toPayrollLineResponse).collect(Collectors.toList()));
        return r;
    }

    private EmployeeDtos.PayrollLineResponse toPayrollLineResponse(PayrollLine line) {
        EmployeeDtos.PayrollLineResponse r = new EmployeeDtos.PayrollLineResponse();
        r.setId(line.getId());
        r.setPayrollRunId(line.getPayrollRun().getId());
        r.setEmployeeId(line.getEmployee().getId());
        r.setEmployeeName(line.getEmployee().getFullName());
        r.setBasePay(safe(line.getBasePay()));
        r.setBonus(safe(line.getBonus()));
        r.setDeductions(safe(line.getDeductions()));
        r.setAdvanceDeduction(safe(line.getAdvanceDeduction()));
        r.setNetPay(safe(line.getNetPay()));
        r.setNote(line.getNote());
        return r;
    }

    private BigDecimal safe(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }

    private String defaultText(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
