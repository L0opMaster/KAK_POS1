package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.dto.CustomerDtos;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-08-11T10:57:04+0700",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 17.0.19 (Ubuntu)"
)
@Component
public class CustomerMapperImpl implements CustomerMapper {

    @Override
    public CustomerDtos.CustomerResponse toResponse(Customer customer) {
        if ( customer == null ) {
            return null;
        }

        CustomerDtos.CustomerResponse customerResponse = new CustomerDtos.CustomerResponse();

        customerResponse.setCode( customer.getCode() );
        customerResponse.setTotalSales( customer.getTotalSales() );
        customerResponse.setId( customer.getId() );
        customerResponse.setType( customer.getType() );
        customerResponse.setStatus( customer.getStatus() );
        customerResponse.setNameEn( customer.getNameEn() );
        customerResponse.setNameKm( customer.getNameKm() );
        customerResponse.setDisplayName( customer.getDisplayName() );
        customerResponse.setPhone( customer.getPhone() );
        customerResponse.setEmail( customer.getEmail() );
        customerResponse.setAddress( customer.getAddress() );
        customerResponse.setNotes( customer.getNotes() );
        customerResponse.setContactPerson( customer.getContactPerson() );
        customerResponse.setPaymentTerms( customer.getPaymentTerms() );
        customerResponse.setTaxNumber( customer.getTaxNumber() );
        customerResponse.setCreditBalance( customer.getCreditBalance() );
        customerResponse.setCreditLimit( customer.getCreditLimit() );
        customerResponse.setCreditHold( customer.isCreditHold() );
        if ( customer.getCreatedAt() != null ) {
            customerResponse.setCreatedAt( customer.getCreatedAt().toString() );
        }
        if ( customer.getUpdatedAt() != null ) {
            customerResponse.setUpdatedAt( customer.getUpdatedAt().toString() );
        }

        return customerResponse;
    }
}
