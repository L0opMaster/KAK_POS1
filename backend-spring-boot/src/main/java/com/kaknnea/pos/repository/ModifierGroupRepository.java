package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.ModifierGroup;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ModifierGroupRepository extends JpaRepository<ModifierGroup, Long> {
    List<ModifierGroup> findAllByOrderByDisplayOrderAsc();
}
