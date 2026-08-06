package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Store;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoreRepository extends JpaRepository<Store, Long> {
}
