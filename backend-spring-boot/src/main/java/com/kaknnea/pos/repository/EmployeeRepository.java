package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.Employee;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface EmployeeRepository extends JpaRepository<Employee, Long> {
    List<Employee> findAllByActiveTrue(Sort sort);
    List<Employee> findAllByActiveTrueAndStatus(String status, Sort sort);
    long countByActiveTrueAndStatus(String status);

    @Query("select distinct e.position from Employee e where e.active = true and e.position is not null and trim(e.position) <> '' order by e.position")
    List<String> findDistinctActivePositions();

    @Query("select distinct e.department from Employee e where e.active = true and e.department is not null and trim(e.department) <> '' order by e.department")
    List<String> findDistinctActiveDepartments();
}
