package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.CartItemRepository;
import com.kaknnea.pos.repository.CartRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.StoreRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CartServiceTest {

    @Mock
    private CartRepository cartRepository;

    @Mock
    private CartItemRepository cartItemRepository;

    @Mock
    private ProductRepository productRepository;

    @Mock
    private CustomerRepository customerRepository;

    @Mock
    private StoreRepository storeRepository;

    @InjectMocks
    private CartService cartService;

    private Customer customer;
    private Product product;
    private Cart cart;
    private CartItem cartItem;

    @BeforeEach
    void setUp() {
        // Setup test data
        customer = new Customer();
        customer.setId(1L);
        customer.setNameEn("John Doe");
        customer.setNameKm("ចន ដូ");

        product = new Product();
        product.setId(1L);
        product.setNameEn("Khmer Coffee");
        product.setNameKm("កាហ្វេខ្មែរ");
        product.setSku("SKU-001");
        product.setBarcode("BAR-001");
        product.setPrice(new BigDecimal("2.50"));
        product.setCost(new BigDecimal("1.00"));
        product.setActive(true);

        cart = new Cart();
        cart.setId(1L);
        cart.setCustomer(customer);
        cart.setStatus(Cart.CartStatus.ACTIVE);
        cart.setTotalAmount(BigDecimal.ZERO);
        cart.setItemCount(0);
        cart.setItems(new ArrayList<>());

        cartItem = new CartItem();
        cartItem.setId(1L);
        cartItem.setCart(cart);
        cartItem.setProduct(product);
        cartItem.setQuantity(1);
        cartItem.setUnitPrice(product.getPrice());
        cartItem.setDiscountAmount(BigDecimal.ZERO);
        cartItem.calculateTotal();
    }

    // ============ CREATE CART TESTS ============

    @Test
    void testCreateCart_Success() {
        // Given
        when(customerRepository.findById(1L)).thenReturn(Optional.of(customer));
        when(cartRepository.save(any(Cart.class))).thenReturn(cart);

        // When
        Cart result = cartService.createCart(1L, null);

        // Then
        assertNotNull(result);
        assertEquals(1L, result.getId());
        assertEquals(customer.getId(), result.getCustomer().getId());
        assertEquals(Cart.CartStatus.ACTIVE, result.getStatus());
        verify(cartRepository, times(1)).save(any(Cart.class));
    }

    @Test
    void testCreateCart_CustomerNotFound() {
        // Given
        when(customerRepository.findById(999L)).thenReturn(Optional.empty());

        // When & Then
        assertThrows(ApiException.class, () -> cartService.createCart(999L, null));
        verify(cartRepository, never()).save(any(Cart.class));
    }

    // ============ GET CART TESTS ============

    @Test
    void testGetCart_Success() {
        // Given
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));

        // When
        Cart result = cartService.getCart(1L);

        // Then
        assertNotNull(result);
        assertEquals(1L, result.getId());
        assertEquals(Cart.CartStatus.ACTIVE, result.getStatus());
    }

    @Test
    void testGetCart_NotFound() {
        // Given
        when(cartRepository.findById(999L)).thenReturn(Optional.empty());

        // When & Then
        assertThrows(ApiException.class, () -> cartService.getCart(999L));
    }

    @Test
    void testGetActiveCartForCustomer_Success() {
        // Given
        when(cartRepository.findActiveCartByCustomerId(1L)).thenReturn(Optional.of(cart));

        // When
        Optional<Cart> result = cartService.getActiveCartForCustomer(1L);

        // Then
        assertTrue(result.isPresent());
        assertEquals(1L, result.get().getId());
    }

    // ============ ADD ITEM TESTS ============

    @Test
    void testAddItemToCart_Success() {
        // Given
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));
        when(productRepository.findById(1L)).thenReturn(Optional.of(product));
        when(cartItemRepository.findByCartIdAndProductId(1L, 1L)).thenReturn(Optional.empty());
        CartItem savedItem = new CartItem();
        savedItem.setId(1L);
        savedItem.setCart(cart);
        savedItem.setProduct(product);
        savedItem.setQuantity(5);
        savedItem.setUnitPrice(product.getPrice());
        savedItem.setDiscountAmount(BigDecimal.ZERO);
        savedItem.calculateTotal();

        when(cartItemRepository.save(any(CartItem.class))).thenReturn(savedItem);

        // When
        CartItem result = cartService.addItemToCart(1L, 1L, 5);

        // Then
        assertNotNull(result);
        assertEquals(product.getId(), result.getProduct().getId());
        assertEquals(5, result.getQuantity());
        verify(cartItemRepository, times(1)).save(any(CartItem.class));
        verify(cartRepository, times(1)).save(any(Cart.class));
    }

    @Test
    void testAddItemToCart_ProductNotFound() {
        // Given
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));
        when(productRepository.findById(999L)).thenReturn(Optional.empty());

        // When & Then
        assertThrows(ApiException.class, () -> cartService.addItemToCart(1L, 999L, 5));
    }

    @Test
    void testAddItemToCart_InvalidQuantity() {
        // Given
        // When & Then
        assertThrows(IllegalArgumentException.class, () -> cartService.addItemToCart(1L, 1L, 0));
        assertThrows(IllegalArgumentException.class, () -> cartService.addItemToCart(1L, 1L, -5));
        assertThrows(IllegalArgumentException.class, () -> cartService.addItemToCart(1L, 1L, 10001));
    }

    @Test
    void testAddItemToCart_DuplicateItem() {
        // Given
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));
        when(productRepository.findById(1L)).thenReturn(Optional.of(product));
        when(cartItemRepository.findByCartIdAndProductId(1L, 1L)).thenReturn(Optional.of(cartItem));

        CartItem updatedItem = new CartItem();
        updatedItem.setId(1L);
        updatedItem.setCart(cart);
        updatedItem.setProduct(product);
        updatedItem.setQuantity(6); // 1 + 5
        updatedItem.setUnitPrice(product.getPrice());
        updatedItem.setDiscountAmount(BigDecimal.ZERO);
        updatedItem.calculateTotal();

        when(cartItemRepository.save(any(CartItem.class))).thenReturn(updatedItem);

        // When
        CartItem result = cartService.addItemToCart(1L, 1L, 5);

        // Then
        assertNotNull(result);
        assertEquals(6, result.getQuantity());
        verify(cartItemRepository, times(1)).save(any(CartItem.class));
    }

    // ============ UPDATE ITEM TESTS ============

    @Test
    void testUpdateCartItemQuantity_Success() {
        // Given
        when(cartItemRepository.findById(1L)).thenReturn(Optional.of(cartItem));
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));

        CartItem updatedItem = new CartItem();
        updatedItem.setId(1L);
        updatedItem.setCart(cart);
        updatedItem.setProduct(product);
        updatedItem.setQuantity(10);
        updatedItem.setUnitPrice(product.getPrice());
        updatedItem.setDiscountAmount(BigDecimal.ZERO);
        updatedItem.calculateTotal();

        when(cartItemRepository.save(any(CartItem.class))).thenReturn(updatedItem);

        // When
        CartItem result = cartService.updateCartItemQuantity(1L, 1L, 10);

        // Then
        assertNotNull(result);
        assertEquals(10, result.getQuantity());
        verify(cartItemRepository, times(1)).save(any(CartItem.class));
    }

    @Test
    void testUpdateCartItemQuantity_InvalidQuantity() {
        // Given & When & Then
        assertThrows(IllegalArgumentException.class, () -> cartService.updateCartItemQuantity(1L, 1L, 0));
    }

    // ============ REMOVE ITEM TESTS ============

    @Test
    void testRemoveItemFromCart_Success() {
        // Given
        when(cartItemRepository.findById(1L)).thenReturn(Optional.of(cartItem));
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));

        // When
        cartService.removeItemFromCart(1L, 1L);

        // Then
        verify(cartItemRepository, times(1)).deleteById(1L);
        verify(cartRepository, times(1)).save(any(Cart.class));
    }

    @Test
    void testRemoveItemFromCart_ItemNotFound() {
        // Given
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));
        when(cartItemRepository.findById(999L)).thenReturn(Optional.empty());

        // When & Then
        assertThrows(ApiException.class, () -> cartService.removeItemFromCart(1L, 999L));
    }

    // ============ CLEAR CART TESTS ============

    @Test
    void testClearCart_Success() {
        // Given
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));

        // When
        cartService.clearCart(1L);

        // Then
        verify(cartRepository, times(1)).save(any(Cart.class));
    }

    // ============ COMPLETE CART TESTS ============

    @Test
    void testCompleteCart_Success() {
        // Given
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));
        when(cartRepository.save(any(Cart.class))).thenReturn(cart);

        // When
        Cart result = cartService.completeCart(1L);

        // Then
        assertNotNull(result);
        assertEquals(Cart.CartStatus.COMPLETED, result.getStatus());
        verify(cartRepository, times(1)).save(any(Cart.class));
    }

    @Test
    void testCompleteCart_InvalidState() {
        // Given
        cart.setStatus(Cart.CartStatus.COMPLETED);
        when(cartRepository.findById(1L)).thenReturn(Optional.of(cart));

        // When & Then
        assertThrows(IllegalStateException.class, () -> cartService.completeCart(1L));
    }

    // ============ CALCULATE TOTAL TESTS ============

    @Test
    void testCalculateCartTotal_WithMultipleItems() {
        // Given
        CartItem item1 = new CartItem();
        item1.setQuantity(2);
        item1.setUnitPrice(new BigDecimal("10.00"));
        item1.setDiscountAmount(BigDecimal.ZERO);
        item1.calculateTotal(); // Total: 20.00

        CartItem item2 = new CartItem();
        item2.setQuantity(3);
        item2.setUnitPrice(new BigDecimal("5.00"));
        item2.setDiscountAmount(BigDecimal.ZERO);
        item2.calculateTotal(); // Total: 15.00

        when(cartItemRepository.findByCartId(1L)).thenReturn(java.util.List.of(item1, item2));

        // When
        BigDecimal total = cartService.calculateCartTotal(1L);

        // Then
        assertEquals(new BigDecimal("35.00"), total);
    }

    @Test
    void testCalculateCartTotal_WithDiscount() {
        // Given
        CartItem item = new CartItem();
        item.setQuantity(2);
        item.setUnitPrice(new BigDecimal("10.00"));
        item.setDiscountAmount(new BigDecimal("5.00"));
        item.calculateTotal(); // Total: 20 - 5 = 15.00

        when(cartItemRepository.findByCartId(1L)).thenReturn(java.util.List.of(item));

        // When
        BigDecimal total = cartService.calculateCartTotal(1L);

        // Then
        assertEquals(new BigDecimal("15.00"), total);
    }
}
