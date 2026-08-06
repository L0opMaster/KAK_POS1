package com.kaknnea.pos.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

public class EmployeeDtos {
    @Data
    public static class EmployeeRequest {
        private String employeeCode;
        @NotBlank
        private String fullName;
        private String phone;
        private String email;
        private String position;
        private String department;
        private String hireDate;
        @NotNull
        @DecimalMin("0.00")
        private BigDecimal baseSalary = BigDecimal.ZERO;
        private String payType = "MONTHLY";
        private String status = "ACTIVE";
        private Long linkedUserId;
        private String notes;
    }

    @Data
    public static class EmployeeResponse {
        private Long id;
        private String employeeCode;
        private String fullName;
        private String phone;
        private String email;
        private String position;
        private String department;
        private String hireDate;
        private BigDecimal baseSalary;
        private String payType;
        private String status;
        private Long linkedUserId;
        private String linkedUserName;
        private String notes;
        private BigDecimal openAdvanceBalance;
        private BigDecimal unpaidExpenseTotal;
    }

    @Data
    public static class EmployeeStatusRequest {
        private String status = "ACTIVE";
    }

    @Data
    public static class EmployeeMasterDataOption {
        private String value;
        private String label;
        private String source;
    }

    @Data
    public static class EmployeeMasterDataRequest {
        @NotBlank
        private String value;
    }

    @Data
    public static class EmployeeProfileResponse {
        private EmployeeResponse employee;
        private BigDecimal currentMonthPayroll;
        private BigDecimal openAdvanceBalance;
        private BigDecimal unpaidExpenseTotal;
        private List<EmployeeExpenseResponse> expenses;
        private List<EmployeeAdvanceResponse> advances;
        private List<PayrollLineResponse> payrollLines;
    }

    @Data
    public static class EmployeeExpenseRequest {
        @NotNull
        private Long employeeId;
        @NotBlank
        private String expenseDate;
        @NotBlank
        private String description;
        @NotNull
        @DecimalMin("0.01")
        private BigDecimal amount;
        private String paymentMethod = "CASH";
        private String reference;
        private String note;
    }

    @Data
    public static class EmployeeExpenseResponse {
        private Long id;
        private Long employeeId;
        private String employeeName;
        private String expenseDate;
        private String description;
        private BigDecimal amount;
        private String paymentMethod;
        private String reference;
        private String note;
        private String status;
        private String approvedAt;
        private String paidAt;
    }

    @Data
    public static class EmployeeAdvanceRequest {
        @NotNull
        private Long employeeId;
        @NotBlank
        private String advanceDate;
        private String type = "ADVANCE";
        @NotNull
        @DecimalMin("0.01")
        private BigDecimal amount;
        private String repaymentMethod = "PAYROLL_DEDUCTION";
        private Integer installmentCount;
        private BigDecimal installmentAmount;
        private String note;
    }

    @Data
    public static class EmployeeAdvancePaymentRequest {
        @NotBlank
        private String paymentDate;
        @NotNull
        @DecimalMin("0.01")
        private BigDecimal amount;
        private String reference;
    }

    @Data
    public static class EmployeeAdvanceResponse {
        private Long id;
        private Long employeeId;
        private String employeeName;
        private String advanceDate;
        private String type;
        private BigDecimal amount;
        private BigDecimal remainingBalance;
        private String repaymentMethod;
        private Integer installmentCount;
        private BigDecimal installmentAmount;
        private String status;
        private String note;
    }

    @Data
    public static class PayrollRunRequest {
        @NotBlank
        private String periodStart;
        @NotBlank
        private String periodEnd;
        @NotBlank
        private String payDate;
        private String note;
    }

    @Data
    public static class PayrollLineUpdateRequest {
        private BigDecimal basePay = BigDecimal.ZERO;
        private BigDecimal bonus = BigDecimal.ZERO;
        private BigDecimal deductions = BigDecimal.ZERO;
        private BigDecimal advanceDeduction = BigDecimal.ZERO;
        private String note;
    }

    @Data
    public static class PayrollRunResponse {
        private Long id;
        private String periodStart;
        private String periodEnd;
        private String payDate;
        private String status;
        private BigDecimal totalGross;
        private BigDecimal totalDeductions;
        private BigDecimal totalNet;
        private String note;
        private List<PayrollLineResponse> lines;
    }

    @Data
    public static class PayrollLineResponse {
        private Long id;
        private Long payrollRunId;
        private Long employeeId;
        private String employeeName;
        private BigDecimal basePay;
        private BigDecimal bonus;
        private BigDecimal deductions;
        private BigDecimal advanceDeduction;
        private BigDecimal netPay;
        private String note;
    }
}
