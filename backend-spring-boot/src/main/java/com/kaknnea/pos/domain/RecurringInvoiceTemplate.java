package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "recurring_invoice_templates")
@Getter
@Setter
public class RecurringInvoiceTemplate extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(length = 500)
    private String description;

    @Column(nullable = false, length = 20)
    private String frequency; // DAILY, WEEKLY, MONTHLY, YEARLY

    @Column(name = "interval_count", nullable = false)
    private int intervalCount = 1;

    @Column(name = "day_of_week")
    private Integer dayOfWeek;

    @Column(name = "day_of_month")
    private Integer dayOfMonth;

    @Column(name = "month_of_year")
    private Integer monthOfYear;

    @Column(name = "next_run_date", nullable = false)
    private LocalDate nextRunDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(name = "max_occurrences")
    private Integer maxOccurrences;

    @Column(name = "occurrences_count", nullable = false)
    private int occurrencesCount = 0;

    @Column(name = "customer_id")
    private Long customerId;

    @Column(name = "display_name", length = 120)
    private String displayName;

    @Column(name = "payment_terms", length = 60)
    private String paymentTerms = "CASH";

    @Column(name = "delivery_charge", nullable = false, precision = 18, scale = 2)
    private BigDecimal deliveryCharge = BigDecimal.ZERO;

    @Column(name = "other_charge", nullable = false, precision = 18, scale = 2)
    private BigDecimal otherCharge = BigDecimal.ZERO;

    @Column(name = "deposit_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal depositAmount = BigDecimal.ZERO;

    @Column(length = 500)
    private String note;

    @Column(name = "invoice_discount", nullable = false, precision = 18, scale = 2)
    private BigDecimal invoiceDiscount = BigDecimal.ZERO;

    @Column(name = "tax_rate", nullable = false)
    private double taxRate = 0.0;

    @Column(name = "delivery_recipient_name", length = 150)
    private String deliveryRecipientName;

    @Column(name = "delivery_phone", length = 50)
    private String deliveryPhone;

    @Column(name = "delivery_address", length = 255)
    private String deliveryAddress;

    @Column(name = "lines_json", nullable = false, columnDefinition = "LONGTEXT")
    private String linesJson;

    @Column(nullable = false)
    private boolean active = true;

    @Column(name = "last_generated_at")
    private java.time.Instant lastGeneratedAt;

    @Column(name = "last_invoice_id")
    private Long lastInvoiceId;
}
