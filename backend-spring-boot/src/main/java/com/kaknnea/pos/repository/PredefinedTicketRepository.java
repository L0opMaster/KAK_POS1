package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PredefinedTicket;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PredefinedTicketRepository extends JpaRepository<PredefinedTicket, Long> {
    List<PredefinedTicket> findByStoreIdAndActiveTrueOrderBySortOrderAscIdAsc(String storeId);

    List<PredefinedTicket> findByStoreIdAndTerminalIdAndActiveTrueOrderBySortOrderAscIdAsc(String storeId,
            String terminalId);
}
