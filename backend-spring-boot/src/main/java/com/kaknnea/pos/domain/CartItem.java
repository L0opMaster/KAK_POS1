package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Table(name = "cart_items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CartItem extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cart_id", nullable = false)
    private Cart cart;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(name = "quantity", nullable = false)
    private int quantity;

    @Column(name = "unit_price", nullable = false, precision = 18, scale = 2)
    private BigDecimal unitPrice;

    @Column(name = "discount_amount", precision = 18, scale = 2)
    private BigDecimal discountAmount = BigDecimal.ZERO;

    @Column(name = "total_price", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalPrice;

    /** Optional note/instruction for this line item (e.g. "no ice", "extra sauce"). */
    @Column(name = "note", length = 500)
    private String note;

    /**
     * Update quantity and recalculate total.
     * Validates quantity is within acceptable range.
     */
    public void updateQuantity(int newQuantity) {
        if (newQuantity <= 0) {
            throw new IllegalArgumentException("Quantity must be greater than 0");
        }
        if (newQuantity > 100000) {
            throw new IllegalArgumentException("Quantity exceeds maximum allowed (100,000)");
        }
        this.quantity = newQuantity;
        calculateTotal();
    }

    /**
     * Calculate total price (unit_price * quantity - discount).
     * Null-safe on all BigDecimal fields.
     */
    public void calculateTotal() {
        BigDecimal safeUnitPrice = unitPrice == null ? BigDecimal.ZERO : unitPrice;
        BigDecimal safeDiscount = discountAmount == null ? BigDecimal.ZERO : discountAmount;
        this.totalPrice = safeUnitPrice
                .multiply(new BigDecimal(quantity))
                .subtract(safeDiscount);
        if (this.totalPrice.compareTo(BigDecimal.ZERO) < 0) {
            this.totalPrice = BigDecimal.ZERO;
        }
    }

    /**
     * Apply discount to item. Also recalculates the total.
     */
    public void applyDiscount(BigDecimal discountAmount) {
        if (discountAmount == null) {
            this.discountAmount = BigDecimal.ZERO;
            calculateTotal();
            return;
        }
        if (discountAmount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Discount amount cannot be negative");
        }
        BigDecimal safeUnitPrice = unitPrice == null ? BigDecimal.ZERO : unitPrice;
        BigDecimal maxDiscount = safeUnitPrice.multiply(new BigDecimal(quantity));
        if (discountAmount.compareTo(maxDiscount) > 0) {
            throw new IllegalArgumentException("Discount cannot exceed item total");
        }
        this.discountAmount = discountAmount;
        calculateTotal();
    }

    /**
     * Get subtotal before discount (unit_price × quantity).
     * Null-safe.
     */
    @Transient
    public BigDecimal getSubtotal() {
        BigDecimal safeUnitPrice = unitPrice == null ? BigDecimal.ZERO : unitPrice;
        return safeUnitPrice.multiply(new BigDecimal(quantity));
    }
}
