package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.SystemSetting;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SystemSettingRepository extends JpaRepository<SystemSetting, Long> {
    Optional<SystemSetting> findByKey(String key);
    List<SystemSetting> findAllByKeyStartingWithOrderByValueAsc(String keyPrefix);
}
