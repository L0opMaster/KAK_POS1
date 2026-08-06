package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Cart;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CartRepository extends JpaRepository<Cart, Long> {
    /**
     * Find active cart for a specific customer
     */
    @Query("SELECT c FROM Cart c WHERE c.customer.id = :customerId AND c.status = 'ACTIVE'")
    Optional<Cart> findActiveCartByCustomerId(@Param("customerId") Long customerId);

    /**
     * Find cart by id and status
     */
    @Query("SELECT c FROM Cart c WHERE c.id = :cartId AND c.status = :status")
    Optional<Cart> findByIdAndStatus(@Param("cartId") Long cartId, @Param("status") String status);

    /**
     * Find all carts for a customer with specific status
     */
    @Query("SELECT c FROM Cart c WHERE c.customer.id = :customerId AND c.status = :status ORDER BY c.createdAt DESC")
    List<Cart> findByCustomerIdAndStatus(@Param("customerId") Long customerId, @Param("status") String status);

    /**
     * Find all active carts for a store
     */
    @Query("SELECT c FROM Cart c WHERE c.store.id = :storeId AND c.status = 'ACTIVE' ORDER BY c.createdAt DESC")
    List<Cart> findActiveCartsByStoreId(@Param("storeId") Long storeId);


}
