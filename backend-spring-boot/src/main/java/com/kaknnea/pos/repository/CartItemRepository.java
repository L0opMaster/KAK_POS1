package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CartItemRepository extends JpaRepository<CartItem, Long> {
    /**
     * Find cart item by cart id and product id
     */
    @Query("SELECT ci FROM CartItem ci WHERE ci.cart.id = :cartId AND ci.product.id = :productId")
    Optional<CartItem> findByCartIdAndProductId(@Param("cartId") Long cartId, @Param("productId") Long productId);

    /**
     * Find all items in a cart
     */
    @Query("SELECT ci FROM CartItem ci WHERE ci.cart.id = :cartId ORDER BY ci.createdAt DESC")
    List<CartItem> findByCartId(@Param("cartId") Long cartId);

    /**
     * Delete item by cart id and product id
     */
    void deleteByCartIdAndProductId(Long cartId, Long productId);

    /**
     * Count items in a cart
     */
    long countByCartId(Long cartId);
}
