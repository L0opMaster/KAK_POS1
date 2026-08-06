package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.*;
import com.kaknnea.pos.dto.PaymentDtos;
import com.kaknnea.pos.repository.CartRepository;
import com.kaknnea.pos.repository.PaymentRepository;
import com.kaknnea.pos.repository.TransactionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PaymentServiceTest {

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private TransactionRepository transactionRepository;

    @Mock
    private CartRepository cartRepository;

    @Mock
    private CreditCollectionService creditCollectionService;

    @InjectMocks
    private PaymentService paymentService;

    private Cart testCart;
    private Customer testCustomer;
    private Store testStore;
    private Payment testPayment;

    @BeforeEach
    void setUp() {
        testCustomer = new Customer();
        testCustomer.setId(1L);
        testCustomer.setNameEn("John Doe");
        testCustomer.setNameKm("ចន ដូ");
        testCustomer.setType("REGULAR");

        testStore = new Store();
        testStore.setId(1L);
        testStore.setName("Main Store");

        Product testProduct = new Product();
        testProduct.setId(1L);
        testProduct.setSku("SKU-001");
        testProduct.setBarcode("BAR-001");
        testProduct.setNameEn("Product 1");
        testProduct.setNameKm("ផលិតផល 1");
        testProduct.setCost(new BigDecimal("50.00"));
        testProduct.setPrice(new BigDecimal("100.00"));

        CartItem cartItem = new CartItem();
        cartItem.setId(1L);
        cartItem.setProduct(testProduct);
        cartItem.setQuantity(1);
        cartItem.setUnitPrice(new BigDecimal("100.00"));
        cartItem.setDiscountAmount(BigDecimal.ZERO);
        cartItem.calculateTotal();

        testCart = new Cart();
        testCart.setId(1L);
        testCart.setCustomer(testCustomer);
        testCart.setStore(testStore);
        testCart.setTotalAmount(new BigDecimal("100.00"));
        testCart.setStatus(Cart.CartStatus.ACTIVE);
        testCart.setItems(new ArrayList<>(List.of(cartItem)));
        cartItem.setCart(testCart);

        testPayment = new Payment();
        testPayment.setId(1L);
        testPayment.setCart(testCart);
        testPayment.setCustomer(testCustomer);
        testPayment.setStore(testStore);
        testPayment.setAmount(new BigDecimal("100.00"));
        testPayment.setCurrency("USD");
        testPayment.setStatus(Payment.PaymentStatus.PENDING);
        testPayment.setPaymentMethod(Payment.PaymentMethod.CREDIT_CARD);
        testPayment.setReferenceNumber("PAY-12345");
    }

    @Test
    void testCreatePayment_Success() {
        // Arrange
        PaymentDtos.CreatePaymentRequest request = PaymentDtos.CreatePaymentRequest.builder()
                .cartId(1L)
                .paymentMethod("CREDIT_CARD")
                .notes("Test payment")
                .build();

        when(cartRepository.findById(1L)).thenReturn(Optional.of(testCart));
        when(paymentRepository.save(any(Payment.class))).thenReturn(testPayment);

        // Act
        PaymentDtos.PaymentResponse response = paymentService.createPayment(request);

        // Assert
        assertNotNull(response);
        assertEquals(1L, response.getId());
        assertEquals(Payment.PaymentStatus.PENDING.name(), response.getStatus());
        assertEquals(new BigDecimal("100.00"), response.getAmount());
        verify(paymentRepository, times(2)).save(any(Payment.class));
    }

    @Test
    void testCreatePayment_CartNotFound() {
        // Arrange
        PaymentDtos.CreatePaymentRequest request = PaymentDtos.CreatePaymentRequest.builder()
                .cartId(999L)
                .paymentMethod("CREDIT_CARD")
                .build();

        when(cartRepository.findById(999L)).thenReturn(Optional.empty());

        // Act & Assert
        assertThrows(RuntimeException.class, () -> paymentService.createPayment(request));
    }

    @Test
    void testCreatePayment_InactiveCart() {
        // Arrange
        testCart.setStatus(Cart.CartStatus.COMPLETED);
        PaymentDtos.CreatePaymentRequest request = PaymentDtos.CreatePaymentRequest.builder()
                .cartId(1L)
                .paymentMethod("CREDIT_CARD")
                .build();

        when(cartRepository.findById(1L)).thenReturn(Optional.of(testCart));

        // Act & Assert
        assertThrows(RuntimeException.class, () -> paymentService.createPayment(request));
    }

    @Test
    void testCreatePayment_EmptyCart() {
        // Arrange
        testCart.setItems(new ArrayList<>());
        PaymentDtos.CreatePaymentRequest request = PaymentDtos.CreatePaymentRequest.builder()
                .cartId(1L)
                .paymentMethod("CREDIT_CARD")
                .build();

        when(cartRepository.findById(1L)).thenReturn(Optional.of(testCart));

        // Act & Assert
        assertThrows(RuntimeException.class, () -> paymentService.createPayment(request));
    }

    @Test
    void testGetPayment_Success() {
        // Arrange
        when(paymentRepository.findById(1L)).thenReturn(Optional.of(testPayment));

        // Act
        PaymentDtos.PaymentResponse response = paymentService.getPayment(1L);

        // Assert
        assertNotNull(response);
        assertEquals(1L, response.getId());
        assertEquals(new BigDecimal("100.00"), response.getAmount());
    }

    @Test
    void testGetPayment_NotFound() {
        // Arrange
        when(paymentRepository.findById(999L)).thenReturn(Optional.empty());

        // Act & Assert
        assertThrows(RuntimeException.class, () -> paymentService.getPayment(999L));
    }

    @Test
    void testGetPaymentByCart_Success() {
        // Arrange
        when(paymentRepository.findByCartId(1L)).thenReturn(Optional.of(testPayment));

        // Act
        PaymentDtos.PaymentResponse response = paymentService.getPaymentByCart(1L);

        // Assert
        assertNotNull(response);
        assertEquals(1L, response.getId());
    }

    @Test
    void testGetPaymentStatus_Success() {
        // Arrange
        when(paymentRepository.findById(1L)).thenReturn(Optional.of(testPayment));

        // Act
        PaymentDtos.PaymentStatusResponse response = paymentService.getPaymentStatus(1L);

        // Assert
        assertNotNull(response);
        assertEquals(1L, response.getPaymentId());
        assertEquals(Payment.PaymentStatus.PENDING.name(), response.getStatus());
        assertTrue(response.getIsCompleted() != null);
    }

    @Test
    void testProcessPayment_Success() {
        // Arrange
        PaymentDtos.ProcessPaymentRequest request = PaymentDtos.ProcessPaymentRequest.builder()
                .paymentId(1L)
                .cardToken("4532123456789010")
                .gatewayId("gateway-123")
                .notes("Processing test payment")
                .build();

        when(paymentRepository.findById(1L)).thenReturn(Optional.of(testPayment));
        when(transactionRepository.save(any(Transaction.class))).thenAnswer(invocation -> {
            Transaction t = invocation.getArgument(0);
            t.setId(1L);
            return t;
        });
        when(paymentRepository.save(any(Payment.class))).thenReturn(testPayment);

        // Act
        PaymentDtos.PaymentResponse response = paymentService.processPayment(request);

        // Assert
        assertNotNull(response);
        verify(transactionRepository, atLeast(1)).save(any(Transaction.class));
        verify(paymentRepository, atLeast(1)).save(any(Payment.class));
    }

    @Test
    void testProcessPayment_PaymentNotPending() {
        // Arrange
        testPayment.setStatus(Payment.PaymentStatus.COMPLETED);
        PaymentDtos.ProcessPaymentRequest request = PaymentDtos.ProcessPaymentRequest.builder()
                .paymentId(1L)
                .cardToken("4532123456789010")
                .build();

        when(paymentRepository.findById(1L)).thenReturn(Optional.of(testPayment));

        // Act & Assert
        assertThrows(RuntimeException.class, () -> paymentService.processPayment(request));
    }

    @Test
    void testRefundPayment_Success() {
        // Arrange
        testPayment.setStatus(Payment.PaymentStatus.COMPLETED);
        testPayment.setTransactionId("txn-123");

        PaymentDtos.RefundPaymentRequest request = PaymentDtos.RefundPaymentRequest.builder()
                .paymentId(1L)
                .refundAmount(new BigDecimal("50.00"))
                .reason("Customer request")
                .build();

        when(paymentRepository.findById(1L)).thenReturn(Optional.of(testPayment));
        when(transactionRepository.save(any(Transaction.class))).thenAnswer(invocation -> {
            Transaction t = invocation.getArgument(0);
            t.setId(2L);
            return t;
        });
        when(paymentRepository.save(any(Payment.class))).thenReturn(testPayment);

        // Act
        PaymentDtos.PaymentResponse response = paymentService.refundPayment(request);

        // Assert
        assertNotNull(response);
        verify(transactionRepository, times(1)).save(any(Transaction.class));
    }

    @Test
    void testRefundPayment_NotRefundable() {
        // Arrange
        testPayment.setStatus(Payment.PaymentStatus.FAILED);
        PaymentDtos.RefundPaymentRequest request = PaymentDtos.RefundPaymentRequest.builder()
                .paymentId(1L)
                .refundAmount(new BigDecimal("50.00"))
                .reason("Customer request")
                .build();

        when(paymentRepository.findById(1L)).thenReturn(Optional.of(testPayment));

        // Act & Assert
        assertThrows(RuntimeException.class, () -> paymentService.refundPayment(request));
    }

    @Test
    void testRefundPayment_InvalidAmount() {
        // Arrange
        PaymentDtos.RefundPaymentRequest request = PaymentDtos.RefundPaymentRequest.builder()
                .paymentId(1L)
                .refundAmount(BigDecimal.ZERO)
                .reason("Customer request")
                .build();

        // Act & Assert
        assertThrows(IllegalArgumentException.class, () -> request.validate());
    }

    @Test
    void testGetCustomerPayments() {
        // Arrange
        List<Payment> payments = Arrays.asList(testPayment);
        when(paymentRepository.findByCustomerOrSaleCustomerId(1L)).thenReturn(payments);

        // Act
        PaymentDtos.PaymentListResponse response = paymentService.getCustomerPayments(1L);

        // Assert
        assertNotNull(response);
        assertEquals(1, response.getTotalCount());
        assertEquals(1, response.getPayments().size());
    }

    @Test
    void testGetCustomerPayments_IncludesSaleLinkedPaymentCustomer() {
        // Arrange
        Sale sale = new Sale();
        sale.setId(22L);
        sale.setCustomer(testCustomer);

        Payment salePayment = new Payment();
        salePayment.setId(2L);
        salePayment.setSale(sale);
        salePayment.setCustomer(null);
        salePayment.setAmount(new BigDecimal("89.00"));
        salePayment.setCurrency("KHR");
        salePayment.setStatus(Payment.PaymentStatus.COMPLETED);
        salePayment.setPaymentMethod(Payment.PaymentMethod.CASH);

        when(paymentRepository.findByCustomerOrSaleCustomerId(1L)).thenReturn(List.of(salePayment));

        // Act
        PaymentDtos.PaymentListResponse response = paymentService.getCustomerPayments(1L);

        // Assert
        assertNotNull(response);
        assertEquals(1, response.getTotalCount());
        assertEquals(1L, response.getPayments().get(0).getCustomerId());
        assertEquals(new BigDecimal("89.00"), response.getPayments().get(0).getAmount());
    }

    @Test
    void testGetPaymentsByStatus() {
        // Arrange
        List<Payment> payments = Arrays.asList(testPayment);
        when(paymentRepository.findByStatus(Payment.PaymentStatus.PENDING)).thenReturn(payments);

        // Act
        PaymentDtos.PaymentListResponse response = paymentService.getPaymentsByStatus(Payment.PaymentStatus.PENDING);

        // Assert
        assertNotNull(response);
        assertEquals(1, response.getTotalCount());
    }

    @Test
    void testGetDailyPayments() {
        // Arrange
        List<Payment> payments = Arrays.asList(testPayment);
        when(paymentRepository.findByStatusAndDateRange(
                eq(Payment.PaymentStatus.COMPLETED),
                any(),
                any())).thenReturn(payments);

        // Act
        PaymentDtos.PaymentListResponse response = paymentService.getDailyPayments();

        // Assert
        assertNotNull(response);
        verify(paymentRepository, times(1)).findByStatusAndDateRange(
                eq(Payment.PaymentStatus.COMPLETED),
                any(),
                any());
    }

    @Test
    void testCreatePaymentRequest_Validation() {
        // Arrange
        PaymentDtos.CreatePaymentRequest request = PaymentDtos.CreatePaymentRequest.builder()
                .cartId(-1L)
                .paymentMethod("CREDIT_CARD")
                .build();

        // Act & Assert
        assertThrows(IllegalArgumentException.class, () -> request.validate());
    }

    @Test
    void testCreatePaymentRequest_MissingPaymentMethod() {
        // Arrange
        PaymentDtos.CreatePaymentRequest request = PaymentDtos.CreatePaymentRequest.builder()
                .cartId(1L)
                .paymentMethod("")
                .build();

        // Act & Assert
        assertThrows(IllegalArgumentException.class, () -> request.validate());
    }
}
