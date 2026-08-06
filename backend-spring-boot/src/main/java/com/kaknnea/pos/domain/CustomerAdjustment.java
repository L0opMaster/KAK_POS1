package com.kaknnea.pos.domain;
import jakarta.persistence.*;
import java.math.BigDecimal;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
@Entity
@Table(name = "customer_adjustments")
@Getter @Setter
public class CustomerAdjustment extends BaseEntity {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "customer_id", nullable = false) private Customer customer;
    @Enumerated(EnumType.STRING) @Column(name = "type", nullable = false, length = 20) private AdjustmentType type;
    @Column(name = "reference_number", nullable = false, length = 60) private String referenceNumber;
    @Column(name = "amount", nullable = false, precision = 18, scale = 2) private BigDecimal amount = BigDecimal.ZERO;
    @Column(name = "reason", length = 255) private String reason;
    @Column(name = "note", length = 500) private String note;
    @Column(name = "created_by", length = 150) private String createdBy;
    @Getter @RequiredArgsConstructor
    public enum AdjustmentType {
        CREDIT_NOTE("Credit Note"), DEBIT_NOTE("Debit Note");
        private final String label;
    }
}
