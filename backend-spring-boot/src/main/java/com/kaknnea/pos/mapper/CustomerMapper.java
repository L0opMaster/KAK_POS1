package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.dto.CustomerDtos.CustomerResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Mappings;

@Mapper(componentModel = "spring")
public interface CustomerMapper {
    @Mappings({
        @Mapping(target = "code", source = "code"),
        @Mapping(target = "totalSales", source = "totalSales")
    })
    CustomerResponse toResponse(Customer customer);
}
