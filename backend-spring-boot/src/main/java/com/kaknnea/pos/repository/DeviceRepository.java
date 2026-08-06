package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Device;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DeviceRepository extends JpaRepository<Device, Long> {
    Optional<Device> findByTerminalId(String terminalId);
}
