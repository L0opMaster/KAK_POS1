package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Supplier;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupplierRepository extends JpaRepository<Supplier, Long> {
}
