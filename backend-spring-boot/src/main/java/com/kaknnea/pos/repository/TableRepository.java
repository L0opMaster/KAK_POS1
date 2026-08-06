package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.RestaurantTable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface TableRepository extends JpaRepository<RestaurantTable, Long> {

    Optional<RestaurantTable> findByTableNumber(String tableNumber);

    Page<RestaurantTable> findByStatus(String status, Pageable pageable);

    Page<RestaurantTable> findBySection(String section, Pageable pageable);

    Page<RestaurantTable> findByIsActiveTrue(Pageable pageable);

    @Query("SELECT t FROM RestaurantTable t WHERE t.isActive = true AND t.status = :status ORDER BY t.tableNumber")
    List<RestaurantTable> findActiveByStatus(@Param("status") String status);

    @Query("SELECT t FROM RestaurantTable t WHERE t.isActive = true ORDER BY t.tableNumber")
    List<RestaurantTable> findAllActive();

    long countByIsActive(boolean isActive);

    long countByStatusAndIsActive(String status, boolean isActive);

    long countByStatus(String status);
}
