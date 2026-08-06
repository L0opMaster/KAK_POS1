package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "carts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Cart extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id")
    private Customer customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id", nullable = true)
    private Store store;

    @Column(name = "total_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(name = "item_count", nullable = false)
    private int itemCount = 0;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private CartStatus status = CartStatus.ACTIVE;

    @OneToMany(mappedBy = "cart", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<CartItem> items = new ArrayList<>();

    /**
     * Add item to cart or update quantity if already exists
     */
    public CartItem addItem(CartItem item) {
        // Check if item already exists
        CartItem existingItem = items.stream()
                .filter(ci -> ci.getProduct().getId().equals(item.getProduct().getId()))
                .findFirst()
                .orElse(null);

        if (existingItem != null) {
            // Update quantity instead of adding duplicate
            existingItem.setQuantity(existingItem.getQuantity() + item.getQuantity());
            existingItem.setTotalPrice(
                    existingItem.getUnitPrice()
                            .multiply(new BigDecimal(existingItem.getQuantity()))
                            .subtract(existingItem.getDiscountAmount()));
            return existingItem;
        }

        // Add new item
        item.setCart(this);
        items.add(item);
        return item;
    }

    /**
     * Remove item from cart by product id
     */
    public void removeItem(Long productId) {
        items.removeIf(item -> item.getProduct().getId().equals(productId));
    }

    /**
     * Remove item by cart item id
     */
    public void removeItemById(Long itemId) {
        items.removeIf(item -> item.getId().equals(itemId));
    }

    /**
     * Clear all items from cart
     */
    public void clear() {
        items.clear();
        totalAmount = BigDecimal.ZERO;
        itemCount = 0;
    }

    /**
     * Calculate and update cart total (item count + sum of total prices).
     * Null-safe: treats null totalPrice as zero.
     */
    public void calculateTotal() {
        this.totalAmount = items.stream()
                .map(item -> {
                    BigDecimal tp = item.getTotalPrice();
                    return tp == null ? BigDecimal.ZERO : tp;
                })
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        this.itemCount = items.stream()
                .mapToInt(CartItem::getQuantity)
                .sum();
    }

    /**
     * Update cart status to COMPLETED
     */
    public void complete() {
        this.status = CartStatus.COMPLETED;
    }

    /**
     * Update cart status to ABANDONED
     */
    public void abandon() {
        this.status = CartStatus.ABANDONED;
    }

    /**
     * Check if cart is active
     */
    public boolean isActive() {
        return status == CartStatus.ACTIVE;
    }

    /**
     * Check if cart is empty
     */
    public boolean isEmpty() {
        return items.isEmpty();
    }

    /**
     * Cart status enum
     */
    public enum CartStatus {
        ACTIVE,
        COMPLETED,
        ABANDONED
    }
}
