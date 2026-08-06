package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.CustomerCreditAccount;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CustomerCreditAccountRepository extends JpaRepository<CustomerCreditAccount, Long> {
    Optional<CustomerCreditAccount> findByCustomerId(Long customerId);
}
