package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "employees")
@Getter
@Setter
public class Employee extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "employee_code", length = 30, unique = true)
    private String employeeCode;

    @Column(name = "full_name", nullable = false, length = 140)
    private String fullName;

    @Column(length = 40)
    private String phone;

    @Column(length = 150)
    private String email;

    @Column(length = 80)
    private String position;

    @Column(length = 80)
    private String department;

    @Column(name = "hire_date")
    private LocalDate hireDate;

    @Column(name = "base_salary", nullable = false, precision = 15, scale = 2)
    private BigDecimal baseSalary = BigDecimal.ZERO;

    @Column(name = "pay_type", nullable = false, length = 20)
    private String payType = "MONTHLY";

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "linked_user_id")
    private User linkedUser;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(nullable = false)
    private boolean active = true;
}
