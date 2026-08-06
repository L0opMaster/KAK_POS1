package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.dto.CartDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.CartItemRepository;
import com.kaknnea.pos.repository.CartRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.StoreRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Slf4j
@Service
@Transactional
@RequiredArgsConstructor
public class CartService {
    private final CartRepository cartRepository;
    private final CartItemRepository cartItemRepository;
    private final ProductRepository productRepository;
    private final CustomerRepository customerRepository;
    private final StoreRepository storeRepository;

    /**
     * Create a new cart for a customer and store
     */
    public Cart createCart(Long customerId, Long storeId) {
        log.info("Creating new cart for customer: {} in store: {}", customerId, storeId);

        Customer customer = customerRepository.findById(customerId)
                .orElseThrow(() -> new ApiException("Customer not found: " + customerId));

        Cart cart = new Cart();
        cart.setCustomer(customer);
        // Store is optional for now
        if (storeId != null) {
            Store store = storeRepository.findById(storeId)
                    .orElseThrow(() -> new ApiException("Store not found: " + storeId));
            cart.setStore(store);
        }
        cart.setStatus(Cart.CartStatus.ACTIVE);
        cart.setTotalAmount(BigDecimal.ZERO);
        cart.setItemCount(0);

        return cartRepository.save(cart);
    }

    /**
     * Get cart by id
     */
    @Transactional(readOnly = true)
    public Cart getCart(Long cartId) {
        log.debug("Fetching cart: {}", cartId);
        return cartRepository.findById(cartId)
                .orElseThrow(() -> new ApiException("Cart not found: " + cartId));
    }

    /**
     * Get active cart for a customer
     */
    @Transactional(readOnly = true)
    public Optional<Cart> getActiveCartForCustomer(Long customerId) {
        log.debug("Fetching active cart for customer: {}", customerId);
        return cartRepository.findActiveCartByCustomerId(customerId);
    }

    /**
     * Add item to cart
     */
    public CartItem addItemToCart(Long cartId, Long productId, int quantity) {
        log.info("Adding item to cart. CartId: {}, ProductId: {}, Quantity: {}", cartId, productId, quantity);

        validateQuantity(quantity);

        Cart cart = getCart(cartId);
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new ApiException("Product not found: " + productId));

        // Check if item already exists
        Optional<CartItem> existingItem = cartItemRepository.findByCartIdAndProductId(cartId, productId);

        if (existingItem.isPresent()) {
            log.info("Item already exists in cart, updating quantity");
            CartItem item = existingItem.get();
            item.updateQuantity(item.getQuantity() + quantity);
            CartItem saved = cartItemRepository.save(item);
            cart.calculateTotal();
            cartRepository.save(cart);
            return saved;
        }

        // Create new cart item
        BigDecimal unitPrice = product.getPrice();
        if (unitPrice == null || unitPrice.compareTo(BigDecimal.ZERO) < 0) {
            unitPrice = BigDecimal.ZERO;
        }
        CartItem newItem = new CartItem();
        newItem.setCart(cart);
        newItem.setProduct(product);
        newItem.setQuantity(quantity);
        newItem.setUnitPrice(unitPrice);
        newItem.setDiscountAmount(BigDecimal.ZERO);
        newItem.calculateTotal();

        // Ensure item is linked to cart before saving
        newItem.setCart(cart);
        CartItem saved = cartItemRepository.save(newItem);

        // Refresh the cart's item collection from DB to keep in sync
        cart.getItems().add(saved);
        cart.calculateTotal();
        cartRepository.save(cart);

        log.info("Successfully added item to cart");
        return saved;
    }

    /**
     * Update cart item quantity
     */
    public CartItem updateCartItemQuantity(Long cartId, Long cartItemId, int newQuantity) {
        log.info("Updating cart item quantity. CartId: {}, ItemId: {}, NewQuantity: {}", cartId, cartItemId,
                newQuantity);

        validateQuantity(newQuantity);

        CartItem item = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new ApiException("Cart item not found: " + cartItemId));

        if (!item.getCart().getId().equals(cartId)) {
            throw new ApiException("Cart item does not belong to this cart");
        }

        item.updateQuantity(newQuantity);
        CartItem saved = cartItemRepository.save(item);

        // Recalculate cart total
        Cart cart = getCart(cartId);
        cart.calculateTotal();
        cartRepository.save(cart);

        log.info("Successfully updated cart item quantity");
        return saved;
    }

    /**
     * Remove item from cart
     */
    public void removeItemFromCart(Long cartId, Long cartItemId) {
        log.info("Removing item from cart. CartId: {}, ItemId: {}", cartId, cartItemId);

        Cart cart = getCart(cartId);
        CartItem item = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new ApiException("Cart item not found: " + cartItemId));

        if (!item.getCart().getId().equals(cartId)) {
            throw new ApiException("Cart item does not belong to this cart");
        }

        cartItemRepository.deleteById(cartItemId);

        // Recalculate cart total
        cart.removeItemById(cartItemId);
        cart.calculateTotal();
        cartRepository.save(cart);

        log.info("Successfully removed item from cart");
    }

    /**
     * Remove item from cart by product id
     */
    public void removeItemFromCartByProductId(Long cartId, Long productId) {
        log.info("Removing item from cart by product id. CartId: {}, ProductId: {}", cartId, productId);

        Cart cart = getCart(cartId);
        cartItemRepository.deleteByCartIdAndProductId(cartId, productId);

        // Recalculate cart total
        cart.removeItem(productId);
        cart.calculateTotal();
        cartRepository.save(cart);

        log.info("Successfully removed item from cart");
    }

    /**
     * Clear all items from cart
     */
    public void clearCart(Long cartId) {
        log.info("Clearing cart: {}", cartId);

        Cart cart = getCart(cartId);
        cart.clear();
        cartRepository.save(cart);

        log.info("Successfully cleared cart");
    }

    /**
     * Get cart items
     */
    @Transactional(readOnly = true)
    public List<CartItem> getCartItems(Long cartId) {
        log.debug("Fetching cart items for cart: {}", cartId);
        return cartItemRepository.findByCartId(cartId);
    }

    /**
     * Complete cart (change status to COMPLETED)
     */
    public Cart completeCart(Long cartId) {
        log.info("Completing cart: {}", cartId);

        Cart cart = getCart(cartId);

        if (!cart.isActive()) {
            throw new IllegalStateException("Cannot complete a cart that is not active");
        }

        cart.complete();
        return cartRepository.save(cart);
    }

    /**
     * Abandon cart (change status to ABANDONED)
     */
    public Cart abandonCart(Long cartId) {
        log.info("Abandoning cart: {}", cartId);

        Cart cart = getCart(cartId);
        cart.abandon();
        return cartRepository.save(cart);
    }

    /**
     * Calculate cart total
     */
    @Transactional(readOnly = true)
    public BigDecimal calculateCartTotal(Long cartId) {
        log.debug("Calculating cart total for cart: {}", cartId);

        List<CartItem> items = getCartItems(cartId);
        return items.stream()
                .map(CartItem::getTotalPrice)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /**
     * Get cart item count
     */
    @Transactional(readOnly = true)
    public int getItemCount(Long cartId) {
        log.debug("Getting item count for cart: {}", cartId);

        List<CartItem> items = getCartItems(cartId);
        return items.stream()
                .mapToInt(CartItem::getQuantity)
                .sum();
    }

    /**
     * Validate quantity
     */
    private void validateQuantity(int quantity) {
        if (quantity <= 0) {
            throw new IllegalArgumentException("Quantity must be greater than 0");
        }
        if (quantity > 10000) {
            throw new IllegalArgumentException("Quantity cannot exceed 10000");
        }
    }

    /**
     * Partial update of a cart item — only the fields present in the request are changed.
     * Supports: unitPrice override, discountAmount, and note.
     */
    public CartItem patchCartItem(Long cartId, Long cartItemId, CartDtos.PatchItemRequest request) {
        log.info("Patching cart item. CartId: {}, ItemId: {}", cartId, cartItemId);

        CartItem item = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new ApiException("Cart item not found: " + cartItemId));

        if (!item.getCart().getId().equals(cartId)) {
            throw new ApiException("Cart item does not belong to this cart");
        }

        boolean recalculate = false;

        if (request.getUnitPrice() != null) {
            BigDecimal newPrice = request.getUnitPrice();
            if (newPrice.compareTo(BigDecimal.ZERO) < 0) {
                throw new ApiException("Unit price cannot be negative");
            }
            item.setUnitPrice(newPrice);
            recalculate = true;
        }

        if (request.getDiscountAmount() != null) {
            item.applyDiscount(request.getDiscountAmount());
            recalculate = false; // applyDiscount already recalculates
        }

        if (request.getNote() != null) {
            String trimmed = request.getNote().trim();
            item.setNote(trimmed.isEmpty() ? null : trimmed);
        }

        if (recalculate) {
            item.calculateTotal();
        }

        CartItem saved = cartItemRepository.save(item);

        // Recalculate cart total
        Cart cart = getCart(cartId);
        cart.calculateTotal();
        cartRepository.save(cart);

        log.info("Successfully patched cart item");
        return saved;
    }
}
