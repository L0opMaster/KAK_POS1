package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.ModifierOption;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ModifierOptionRepository extends JpaRepository<ModifierOption, Long> {
    List<ModifierOption> findByGroupIdOrderByDisplayOrderAsc(Long groupId);
}
