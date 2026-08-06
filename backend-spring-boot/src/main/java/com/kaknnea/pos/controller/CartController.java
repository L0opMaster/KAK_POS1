package com.kaknnea.pos.controller;

import com.kaknnea.pos.domain.Cart;
import com.kaknnea.pos.domain.CartItem;
import com.kaknnea.pos.dto.CartDtos;
import com.kaknnea.pos.service.CartService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping("/api/carts")
@RequiredArgsConstructor
public class CartController {
    private final CartService cartService;

    /**
     * Create a new cart
     */
    @PostMapping
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public ResponseEntity<CartDtos.CartResponse> createCart(
            @Valid @RequestBody CartDtos.CreateCartRequest request) {
        log.info("Creating new cart for customer: {}", request.getCustomerId());

        Cart cart = cartService.createCart(request.getCustomerId(), request.getStoreId());
        CartDtos.CartResponse response = mapCartToResponse(cart);

        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    /**
     * Get cart by id
     */
    @GetMapping("/{cartId}")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public ResponseEntity<CartDtos.CartResponse> getCart(@PathVariable Long cartId) {
        log.info("Fetching cart: {}", cartId);

        Cart cart = cartService.getCart(cartId);
        CartDtos.CartResponse response = mapCartToResponse(cart);

        return ResponseEntity.ok(response);
    }

    /**
     * Add item to cart
     */
    @PostMapping("/{cartId}/items")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public ResponseEntity<CartDtos.CartItemResponse> addItemToCart(
            @PathVariable Long cartId,
            @Valid @RequestBody CartDtos.AddItemRequest request) {
        log.info("Adding item to cart. CartId: {}, ProductId: {}, Quantity: {}",
                cartId, request.getProductId(), request.getQuantity());

        CartItem cartItem = cartService.addItemToCart(cartId, request.getProductId(), request.getQuantity());
        CartDtos.CartItemResponse response = mapCartItemToResponse(cartItem);

        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    /**
     * Update cart item quantity
     */
    @PutMapping("/{cartId}/items/{itemId}")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public ResponseEntity<CartDtos.CartItemResponse> updateItemQuantity(
            @PathVariable Long cartId,
            @PathVariable Long itemId,
            @Valid @RequestBody CartDtos.UpdateItemRequest request) {
        log.info("Updating item quantity. CartId: {}, ItemId: {}, NewQuantity: {}",
                cartId, itemId, request.getQuantity());

        CartItem cartItem = cartService.updateCartItemQuantity(cartId, itemId, request.getQuantity());
        CartDtos.CartItemResponse response = mapCartItemToResponse(cartItem);

        return ResponseEntity.ok(response);
    }
    
    /**
     * Partially update a cart item (price override, discount, note).
     * All fields in the request body are optional.
     */
    @PatchMapping("/{cartId}/items/{itemId}")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public ResponseEntity<CartDtos.CartItemResponse> patchItem(
            @PathVariable Long cartId,
            @PathVariable Long itemId,
            @Valid @RequestBody CartDtos.PatchItemRequest request) {
        log.info("Patching cart item. CartId: {}, ItemId: {}", cartId, itemId);

        CartItem cartItem = cartService.patchCartItem(cartId, itemId, request);
        CartDtos.CartItemResponse response = mapCartItemToResponse(cartItem);

        return ResponseEntity.ok(response);
    }

    /**
     * Remove item from cart by item id
     */
    @DeleteMapping("/{cartId}/items/{itemId}")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public ResponseEntity<Void> removeItemFromCart(
            @PathVariable Long cartId,
            @PathVariable Long itemId) {
        log.info("Removing item from cart. CartId: {}, ItemId: {}", cartId, itemId);

        cartService.removeItemFromCart(cartId, itemId);

        return ResponseEntity.noContent().build();
    }

    /**
     * Clear all items from cart
     */
    @DeleteMapping("/{cartId}")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public ResponseEntity<Void> clearCart(@PathVariable Long cartId) {
        log.info("Clearing cart: {}", cartId);

        cartService.clearCart(cartId);

        return ResponseEntity.noContent().build();
    }

    /**
     * Complete/checkout cart
     */
    @PostMapping("/{cartId}/checkout")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public ResponseEntity<CartDtos.CartCheckoutResponse> completeCart(@PathVariable Long cartId) {
        log.info("Completing cart: {}", cartId);

        Cart cart = cartService.completeCart(cartId);

        CartDtos.CartCheckoutResponse response = new CartDtos.CartCheckoutResponse();
        response.setCartId(cart.getId());
        response.setStatus(cart.getStatus().toString());
        response.setTotalAmount(cart.getTotalAmount());
        response.setItemCount(cart.getItemCount());
        response.setCompletedAt(cart.getUpdatedAt());
        response.setMessage("Cart completed successfully");

        return ResponseEntity.ok(response);
    }

    /**
     * Map Cart entity to CartResponse DTO
     */
    private CartDtos.CartResponse mapCartToResponse(Cart cart) {
        CartDtos.CartResponse response = new CartDtos.CartResponse();
        response.setId(cart.getId());
        response.setCustomerId(cart.getCustomer().getId());
        response.setCustomerNameEn(cart.getCustomer().getNameEn());
        response.setCustomerNameKm(cart.getCustomer().getNameKm());
        response.setStoreId(cart.getStore().getId());
        response.setStoreName(cart.getStore().getName());
        response.setStatus(cart.getStatus().toString());
        response.setTotalAmount(cart.getTotalAmount());
        response.setItemCount(cart.getItemCount());
        response.setCreatedAt(cart.getCreatedAt());
        response.setUpdatedAt(cart.getUpdatedAt());

        List<CartDtos.CartItemResponse> items = cart.getItems().stream()
                .map(this::mapCartItemToResponse)
                .collect(Collectors.toList());
        response.setItems(items);

        return response;
    }

    /**
     * Map CartItem entity to CartItemResponse DTO
     */
    private CartDtos.CartItemResponse mapCartItemToResponse(CartItem item) {
        CartDtos.CartItemResponse response = new CartDtos.CartItemResponse();
        response.setId(item.getId());
        response.setProductId(item.getProduct().getId());
        response.setProductNameEn(item.getProduct().getNameEn());
        response.setProductNameKm(item.getProduct().getNameKm());
        response.setProductSku(item.getProduct().getSku());
        response.setQuantity(item.getQuantity());
        response.setUnitPrice(item.getUnitPrice());
        response.setDiscountAmount(item.getDiscountAmount());
        response.setTotalPrice(item.getTotalPrice());
        response.setSubtotal(item.getSubtotal());
        response.setNote(item.getNote());
        response.setCreatedAt(item.getCreatedAt());
        response.setUpdatedAt(item.getUpdatedAt());

        return response;
    }
}
