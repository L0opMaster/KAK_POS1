package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.BusinessSettings;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusinessSettingsRepository extends JpaRepository<BusinessSettings, Long> {
    Optional<BusinessSettings> findFirstByOrderByIdAsc();
}
