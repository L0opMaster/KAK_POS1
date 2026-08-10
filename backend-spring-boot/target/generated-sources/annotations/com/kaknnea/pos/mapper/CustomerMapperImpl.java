package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.dto.CustomerDtos;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-08-10T13:50:22+0700",
    comments = "version: 1.5.5.Final, compiler: Eclipse JDT (IDE) 3.46.100.v20260624-0231, environment: Java 21.0.11 (Eclipse Adoptium)"
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
        customerResponse.setAddress( customer.getAddress() );
        customerResponse.setContactPerson( customer.getContactPerson() );
        if ( customer.getCreatedAt() != null ) {
            customerResponse.setCreatedAt( customer.getCreatedAt().toString() );
        }
        customerResponse.setCreditBalance( customer.getCreditBalance() );
        customerResponse.setCreditHold( customer.isCreditHold() );
        customerResponse.setCreditLimit( customer.getCreditLimit() );
        customerResponse.setDisplayName( customer.getDisplayName() );
        customerResponse.setEmail( customer.getEmail() );
        customerResponse.setId( customer.getId() );
        customerResponse.setNameEn( customer.getNameEn() );
        customerResponse.setNameKm( customer.getNameKm() );
        customerResponse.setNotes( customer.getNotes() );
        customerResponse.setPaymentTerms( customer.getPaymentTerms() );
        customerResponse.setPhone( customer.getPhone() );
        customerResponse.setStatus( customer.getStatus() );
        customerResponse.setTaxNumber( customer.getTaxNumber() );
        customerResponse.setType( customer.getType() );
        if ( customer.getUpdatedAt() != null ) {
            customerResponse.setUpdatedAt( customer.getUpdatedAt().toString() );
        }

        return customerResponse;
    }
}
