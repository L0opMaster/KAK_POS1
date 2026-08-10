package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.BusinessSettings;
import com.kaknnea.pos.domain.InvoiceSettings;
import com.kaknnea.pos.dto.SettingsDtos;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-08-10T13:50:22+0700",
    comments = "version: 1.5.5.Final, compiler: Eclipse JDT (IDE) 3.46.100.v20260624-0231, environment: Java 21.0.11 (Eclipse Adoptium)"
)
@Component
public class SettingsMapperImpl implements SettingsMapper {

    @Override
    public BusinessSettings toBusinessEntity(SettingsDtos.BusinessSettingsRequest request) {
        if ( request == null ) {
            return null;
        }

        BusinessSettings businessSettings = new BusinessSettings();

        businessSettings.setAddress( request.getAddress() );
        businessSettings.setBusinessName( request.getBusinessName() );
        businessSettings.setCurrency( request.getCurrency() );
        businessSettings.setDefaultLanguage( request.getDefaultLanguage() );
        businessSettings.setLogoUrl( request.getLogoUrl() );
        businessSettings.setPhone( request.getPhone() );
        businessSettings.setReceiptFooter( request.getReceiptFooter() );
        if ( request.getRequireShiftForSales() != null ) {
            businessSettings.setRequireShiftForSales( request.getRequireShiftForSales() );
        }
        businessSettings.setTaxRate( request.getTaxRate() );

        return businessSettings;
    }

    @Override
    public SettingsDtos.BusinessSettingsResponse toBusinessResponse(BusinessSettings entity) {
        if ( entity == null ) {
            return null;
        }

        SettingsDtos.BusinessSettingsResponse businessSettingsResponse = new SettingsDtos.BusinessSettingsResponse();

        businessSettingsResponse.setAddress( entity.getAddress() );
        businessSettingsResponse.setBusinessName( entity.getBusinessName() );
        businessSettingsResponse.setCurrency( entity.getCurrency() );
        businessSettingsResponse.setDefaultLanguage( entity.getDefaultLanguage() );
        businessSettingsResponse.setId( entity.getId() );
        businessSettingsResponse.setLogoUrl( entity.getLogoUrl() );
        businessSettingsResponse.setPhone( entity.getPhone() );
        businessSettingsResponse.setReceiptFooter( entity.getReceiptFooter() );
        businessSettingsResponse.setRequireShiftForSales( entity.isRequireShiftForSales() );
        businessSettingsResponse.setTaxRate( entity.getTaxRate() );

        return businessSettingsResponse;
    }

    @Override
    public InvoiceSettings toInvoiceEntity(SettingsDtos.InvoiceSettingsRequest request) {
        if ( request == null ) {
            return null;
        }

        InvoiceSettings invoiceSettings = new InvoiceSettings();

        invoiceSettings.setDefaultInvoiceFormat( request.getDefaultInvoiceFormat() );
        invoiceSettings.setDefaultReceiptFormat( request.getDefaultReceiptFormat() );
        invoiceSettings.setFooter( request.getFooter() );
        invoiceSettings.setNextNumber( request.getNextNumber() );
        invoiceSettings.setPrefix( request.getPrefix() );
        invoiceSettings.setPrinterAddress( request.getPrinterAddress() );
        invoiceSettings.setPrinterName( request.getPrinterName() );
        invoiceSettings.setPrinterType( request.getPrinterType() );
        if ( request.getShowKhqr() != null ) {
            invoiceSettings.setShowKhqr( request.getShowKhqr() );
        }
        if ( request.getShowTax() != null ) {
            invoiceSettings.setShowTax( request.getShowTax() );
        }

        return invoiceSettings;
    }

    @Override
    public SettingsDtos.InvoiceSettingsResponse toInvoiceResponse(InvoiceSettings entity) {
        if ( entity == null ) {
            return null;
        }

        SettingsDtos.InvoiceSettingsResponse invoiceSettingsResponse = new SettingsDtos.InvoiceSettingsResponse();

        invoiceSettingsResponse.setDefaultInvoiceFormat( entity.getDefaultInvoiceFormat() );
        invoiceSettingsResponse.setDefaultReceiptFormat( entity.getDefaultReceiptFormat() );
        invoiceSettingsResponse.setFooter( entity.getFooter() );
        invoiceSettingsResponse.setId( entity.getId() );
        invoiceSettingsResponse.setNextNumber( entity.getNextNumber() );
        invoiceSettingsResponse.setPrefix( entity.getPrefix() );
        invoiceSettingsResponse.setPrinterAddress( entity.getPrinterAddress() );
        invoiceSettingsResponse.setPrinterName( entity.getPrinterName() );
        invoiceSettingsResponse.setPrinterType( entity.getPrinterType() );
        invoiceSettingsResponse.setShowKhqr( entity.isShowKhqr() );
        invoiceSettingsResponse.setShowTax( entity.isShowTax() );

        return invoiceSettingsResponse;
    }
}
