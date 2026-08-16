package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "sales")
@Getter
@Setter
public class Sale extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // For restaurant/retail ticket workflows
    @Column(name = "display_name", length = 120)
    private String displayName;

    @Column(name = "comment", length = 255)
    private String comment;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_employee_id")
    private User assignedEmployee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "predefined_ticket_id")
    private PredefinedTicket predefinedTicket;

    @Column(name = "sale_number", length = 50, unique = true)
    private String saleNumber;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    // Added for HeldTicketService compatibility
    @Column(name = "terminal_id", length = 64)
    private String terminalId;

    @Column(name = "closed_reason", length = 255)
    private String closedReason;

    @Column(name = "credit_term_days")
    private Integer creditTermDays;

    @Column(name = "order_date")
    private LocalDate orderDate;

    @Column(name = "delivery_date")
    private LocalDate deliveryDate;

    @Column(name = "payment_terms", length = 60)
    private String paymentTerms;

    @Column(name = "order_mode", length = 20)
    private String orderMode;

    @Column(name = "delivery_recipient_name", length = 150)
    private String deliveryRecipientName;

    @Column(name = "delivery_phone", length = 50)
    private String deliveryPhone;

    @Column(name = "delivery_address", length = 255)
    private String deliveryAddress;

    @Column(name = "delivery_landmark", length = 255)
    private String deliveryLandmark;

    @Column(name = "delivery_note", length = 500)
    private String deliveryNote;

    @Column(name = "delivery_charge", nullable = false, precision = 18, scale = 2)
    private BigDecimal deliveryCharge = BigDecimal.ZERO;

    @Column(name = "other_charge", nullable = false, precision = 18, scale = 2)
    private BigDecimal otherCharge = BigDecimal.ZERO;

    @Column(name = "deposit_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal depositAmount = BigDecimal.ZERO;

    public String getTerminalId() {
        return terminalId;
    }

    public void setTerminalId(String terminalId) {
        this.terminalId = terminalId;
    }

    public String getClosedReason() {
        return closedReason;
    }

    public void setClosedReason(String closedReason) {
        this.closedReason = closedReason;
    }

    public Integer getCreditTermDays() {
        return creditTermDays;
    }

    public void setCreditTermDays(Integer creditTermDays) {
        this.creditTermDays = creditTermDays;
    }

    @Column(name = "subtotal", nullable = false, precision = 18, scale = 2)
    private BigDecimal subtotal;

    @Column(name = "discount_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal discountAmount;

    @Column(name = "tax_rate", nullable = false)
    private double taxRate;

    @Column(name = "tax_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal taxAmount;

    @Column(name = "grand_total", nullable = false, precision = 18, scale = 2)
    private BigDecimal grandTotal;

    @Column(name = "total_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalAmount;

    @Column(name = "paid_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal paidAmount;

    @Column(name = "change_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal changeAmount;

    @Column(name = "note", length = 255)
    private String note;

    @Column(name = "client_ref", length = 64, unique = true)
    private String clientRef;

    @Column(name = "paid_at")
    private Instant paidAt;

    @Column(name = "voided_at")
    private Instant voidedAt;

    @Column(name = "void_reason", length = 500)
    private String voidReason;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id")
    private Customer customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cashier_id")
    private User createdBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shift_id")
    private Shift shift;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "table_id")
    private RestaurantTable table;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "voided_by_id")
    private User voidedBy;

    @OneToMany(mappedBy = "sale", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<SaleLine> lines = new ArrayList<>();

    @OneToMany(mappedBy = "sale", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Payment> payments = new ArrayList<>();

    @OneToMany(mappedBy = "sale", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<SaleDiscount> discounts = new ArrayList<>();

    @Version
    private Long version;

    @Column(name = "credit_issued_at")
    private Instant creditIssuedAt;

    public Instant getCreditIssuedAt() { return creditIssuedAt; }
    public void setCreditIssuedAt(Instant v) { this.creditIssuedAt = v; }

    /**
     * Guards against double stock deduction.
     * Set to true the first time applyStockForSale() runs for this sale.
     * Checked before every call so split-payment or pay+credit race cannot deduct stock twice.
     */
    @Column(name = "stock_applied", nullable = false)
    private boolean stockApplied = false;

    @Column(name = "credit_due_at")
    private Instant creditDueAt;

    public Instant getCreditDueAt() {
        return creditDueAt;
    }

    public void setCreditDueAt(Instant creditDueAt) {
        this.creditDueAt = creditDueAt;
    }

    /**
     * Optional date after which this credit agreement is considered expired.
     * Distinct from {@link #creditDueAt} (when payment is expected) — expiring
     * never changes {@link #status}/{@link #paidAmount} on its own; an expired
     * debt can still carry an outstanding balance.
     */
    @Column(name = "credit_expires_at")
    private Instant creditExpiresAt;

    public Instant getCreditExpiresAt() {
        return creditExpiresAt;
    }

    public void setCreditExpiresAt(Instant creditExpiresAt) {
        this.creditExpiresAt = creditExpiresAt;
    }

    // ── Estimate/Quotation fields ────────────────────────────────────────────

    @Column(name = "estimate_expiry_date")
    private LocalDate estimateExpiryDate;

    @Column(name = "estimate_sent_at")
    private Instant estimateSentAt;

    @Column(name = "estimate_accepted_at")
    private Instant estimateAcceptedAt;

    @Column(name = "estimate_declined_at")
    private Instant estimateDeclinedAt;

    @Column(name = "estimate_decline_reason", length = 500)
    private String estimateDeclineReason;

    @Column(name = "converted_from_estimate_id")
    private Long convertedFromEstimateId;

    /**
     * KHR-per-USD rate in effect when this sale was created, copied from
     * CurrencySetting("KHR").exchangeRate at that moment. Receipts must
     * always convert using this stored value, never the current live rate,
     * so a later rate change in Settings never rewrites an old receipt.
     */
    @Column(name = "exchange_rate_khr", precision = 18, scale = 6)
    private BigDecimal exchangeRateKhr;
}
