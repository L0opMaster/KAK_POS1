package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.EmployeeDtos;
import com.kaknnea.pos.service.EmployeeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class EmployeeController {
    private final EmployeeService employeeService;

    private static final String EMPLOYEE_READ = "hasRole('OWNER') or hasRole('ADMIN') or hasRole('MANAGER') or hasRole('ACCOUNTANT') or hasAuthority('PERM_EMPLOYEE_VIEW') or hasAuthority('PERM_EMPLOYEE_MANAGE') or hasAuthority('PERM_ADMIN')";
    private static final String EMPLOYEE_WRITE = "hasRole('OWNER') or hasRole('ADMIN') or hasRole('MANAGER') or hasAuthority('PERM_EMPLOYEE_MANAGE') or hasAuthority('PERM_ADMIN')";
    private static final String PAYROLL_READ = "hasRole('OWNER') or hasRole('ADMIN') or hasRole('MANAGER') or hasRole('ACCOUNTANT') or hasAuthority('PERM_PAYROLL_VIEW') or hasAuthority('PERM_PAYROLL_MANAGE') or hasAuthority('PERM_ADMIN')";
    private static final String PAYROLL_WRITE = "hasRole('OWNER') or hasRole('ADMIN') or hasRole('ACCOUNTANT') or hasAuthority('PERM_PAYROLL_MANAGE') or hasAuthority('PERM_ADMIN')";

    @GetMapping("/api/employees")
    @PreAuthorize(EMPLOYEE_READ)
    public List<EmployeeDtos.EmployeeResponse> employees(@RequestParam(required = false) String q,
                                                         @RequestParam(required = false) String status,
                                                         @RequestParam(required = false) String department) {
        return employeeService.listEmployees(q, status, department);
    }

    @GetMapping("/api/employees/{id}")
    @PreAuthorize(EMPLOYEE_READ)
    public EmployeeDtos.EmployeeResponse employee(@PathVariable Long id) {
        return employeeService.getEmployee(id);
    }

    @GetMapping("/api/employees/{id}/profile")
    @PreAuthorize(EMPLOYEE_READ)
    public EmployeeDtos.EmployeeProfileResponse profile(@PathVariable Long id) {
        return employeeService.profile(id);
    }

    @PostMapping("/api/employees")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeResponse createEmployee(@Valid @RequestBody EmployeeDtos.EmployeeRequest request) {
        return employeeService.createEmployee(request);
    }

    @PutMapping("/api/employees/{id}")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeResponse updateEmployee(@PathVariable Long id, @Valid @RequestBody EmployeeDtos.EmployeeRequest request) {
        return employeeService.updateEmployee(id, request);
    }

    @PutMapping("/api/employees/{id}/status")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeResponse status(@PathVariable Long id, @RequestBody EmployeeDtos.EmployeeStatusRequest request) {
        return employeeService.setEmployeeStatus(id, request.getStatus());
    }

    @DeleteMapping("/api/employees/{id}")
    @PreAuthorize(EMPLOYEE_WRITE)
    public ResponseEntity<?> deleteEmployee(@PathVariable Long id) {
        employeeService.deleteEmployee(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/employees/master-data/{type}")
    @PreAuthorize(EMPLOYEE_READ)
    public List<EmployeeDtos.EmployeeMasterDataOption> masterData(@PathVariable String type) {
        return employeeService.listMasterData(type);
    }

    @PostMapping("/api/employees/master-data/{type}")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeMasterDataOption addMasterData(@PathVariable String type,
                                                               @Valid @RequestBody EmployeeDtos.EmployeeMasterDataRequest request) {
        return employeeService.addMasterData(type, request);
    }

    @GetMapping("/api/employee-expenses")
    @PreAuthorize(EMPLOYEE_READ)
    public List<EmployeeDtos.EmployeeExpenseResponse> expenses(@RequestParam(required = false) Long employeeId,
                                                               @RequestParam(required = false) String status) {
        return employeeService.listExpenses(employeeId, status);
    }

    @PostMapping("/api/employee-expenses")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeExpenseResponse createExpense(@Valid @RequestBody EmployeeDtos.EmployeeExpenseRequest request) {
        return employeeService.createExpense(request);
    }

    @PostMapping("/api/employee-expenses/{id}/approve")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeExpenseResponse approveExpense(@PathVariable Long id) {
        return employeeService.approveExpense(id);
    }

    @PostMapping("/api/employee-expenses/{id}/mark-paid")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeExpenseResponse markExpensePaid(@PathVariable Long id) {
        return employeeService.markExpensePaid(id);
    }

    @GetMapping("/api/employee-advances")
    @PreAuthorize(EMPLOYEE_READ)
    public List<EmployeeDtos.EmployeeAdvanceResponse> advances(@RequestParam(required = false) Long employeeId,
                                                               @RequestParam(required = false) String status) {
        return employeeService.listAdvances(employeeId, status);
    }

    @GetMapping("/api/employee-advances/{id}")
    @PreAuthorize(EMPLOYEE_READ)
    public EmployeeDtos.EmployeeAdvanceResponse advance(@PathVariable Long id) {
        return employeeService.getAdvance(id);
    }

    @PostMapping("/api/employee-advances")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeAdvanceResponse createAdvance(@Valid @RequestBody EmployeeDtos.EmployeeAdvanceRequest request) {
        return employeeService.createAdvance(request);
    }

    @PutMapping("/api/employee-advances/{id}")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeAdvanceResponse updateAdvance(@PathVariable Long id, @Valid @RequestBody EmployeeDtos.EmployeeAdvanceRequest request) {
        return employeeService.updateAdvance(id, request);
    }

    @PostMapping("/api/employee-advances/{id}/payment")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeAdvanceResponse payAdvance(@PathVariable Long id, @Valid @RequestBody EmployeeDtos.EmployeeAdvancePaymentRequest request) {
        return employeeService.payAdvance(id, request);
    }

    @PostMapping("/api/employee-advances/{id}/cancel")
    @PreAuthorize(EMPLOYEE_WRITE)
    public EmployeeDtos.EmployeeAdvanceResponse cancelAdvance(@PathVariable Long id) {
        return employeeService.cancelAdvance(id);
    }

    @GetMapping("/api/payroll-runs")
    @PreAuthorize(PAYROLL_READ)
    public List<EmployeeDtos.PayrollRunResponse> payrollRuns() {
        return employeeService.listPayrollRuns();
    }

    @GetMapping("/api/payroll-runs/{id}")
    @PreAuthorize(PAYROLL_READ)
    public EmployeeDtos.PayrollRunResponse payrollRun(@PathVariable Long id) {
        return employeeService.getPayrollRun(id);
    }

    @PostMapping("/api/payroll-runs")
    @PreAuthorize(PAYROLL_WRITE)
    public EmployeeDtos.PayrollRunResponse createPayrollRun(@Valid @RequestBody EmployeeDtos.PayrollRunRequest request) {
        return employeeService.createPayrollRun(request);
    }

    @PostMapping("/api/payroll-runs/{id}/generate-lines")
    @PreAuthorize(PAYROLL_WRITE)
    public EmployeeDtos.PayrollRunResponse generateLines(@PathVariable Long id) {
        return employeeService.generatePayrollLines(id);
    }

    @PutMapping("/api/payroll-runs/{id}/lines/{lineId}")
    @PreAuthorize(PAYROLL_WRITE)
    public EmployeeDtos.PayrollRunResponse updatePayrollLine(@PathVariable Long id,
                                                             @PathVariable Long lineId,
                                                             @RequestBody EmployeeDtos.PayrollLineUpdateRequest request) {
        return employeeService.updatePayrollLine(id, lineId, request);
    }

    @PostMapping("/api/payroll-runs/{id}/approve")
    @PreAuthorize(PAYROLL_WRITE)
    public EmployeeDtos.PayrollRunResponse approvePayroll(@PathVariable Long id) {
        return employeeService.approvePayrollRun(id);
    }

    @PostMapping("/api/payroll-runs/{id}/mark-paid")
    @PreAuthorize(PAYROLL_WRITE)
    public EmployeeDtos.PayrollRunResponse markPayrollPaid(@PathVariable Long id) {
        return employeeService.markPayrollPaid(id);
    }

    @DeleteMapping("/api/payroll-runs/{id}")
    @PreAuthorize(PAYROLL_WRITE)
    public ResponseEntity<?> deletePayrollRun(@PathVariable Long id) {
        employeeService.deletePayrollRun(id);
        return ResponseEntity.noContent().build();
    }
}
