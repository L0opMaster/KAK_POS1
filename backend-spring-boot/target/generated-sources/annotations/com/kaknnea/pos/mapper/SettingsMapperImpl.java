package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.BusinessSettings;
import com.kaknnea.pos.domain.InvoiceSettings;
import com.kaknnea.pos.dto.SettingsDtos;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-08-16T12:54:45+0700",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 17.0.19 (Ubuntu)"
)
@Component
public class SettingsMapperImpl implements SettingsMapper {

    @Override
    public BusinessSettings toBusinessEntity(SettingsDtos.BusinessSettingsRequest request) {
        if ( request == null ) {
            return null;
        }

        BusinessSettings businessSettings = new BusinessSettings();

        businessSettings.setBusinessName( request.getBusinessName() );
        businessSettings.setLogoUrl( request.getLogoUrl() );
        businessSettings.setAddress( request.getAddress() );
        businessSettings.setPhone( request.getPhone() );
        businessSettings.setTaxRate( request.getTaxRate() );
        businessSettings.setCurrency( request.getCurrency() );
        businessSettings.setReceiptFooter( request.getReceiptFooter() );
        businessSettings.setDefaultLanguage( request.getDefaultLanguage() );
        if ( request.getRequireShiftForSales() != null ) {
            businessSettings.setRequireShiftForSales( request.getRequireShiftForSales() );
        }

        return businessSettings;
    }

    @Override
    public SettingsDtos.BusinessSettingsResponse toBusinessResponse(BusinessSettings entity) {
        if ( entity == null ) {
            return null;
        }

        SettingsDtos.BusinessSettingsResponse businessSettingsResponse = new SettingsDtos.BusinessSettingsResponse();

        businessSettingsResponse.setId( entity.getId() );
        businessSettingsResponse.setBusinessName( entity.getBusinessName() );
        businessSettingsResponse.setLogoUrl( entity.getLogoUrl() );
        businessSettingsResponse.setAddress( entity.getAddress() );
        businessSettingsResponse.setPhone( entity.getPhone() );
        businessSettingsResponse.setTaxRate( entity.getTaxRate() );
        businessSettingsResponse.setCurrency( entity.getCurrency() );
        businessSettingsResponse.setReceiptFooter( entity.getReceiptFooter() );
        businessSettingsResponse.setDefaultLanguage( entity.getDefaultLanguage() );
        businessSettingsResponse.setRequireShiftForSales( entity.isRequireShiftForSales() );

        return businessSettingsResponse;
    }

    @Override
    public InvoiceSettings toInvoiceEntity(SettingsDtos.InvoiceSettingsRequest request) {
        if ( request == null ) {
            return null;
        }

        InvoiceSettings invoiceSettings = new InvoiceSettings();

        invoiceSettings.setPrefix( request.getPrefix() );
        invoiceSettings.setNextNumber( request.getNextNumber() );
        invoiceSettings.setFooter( request.getFooter() );
        if ( request.getShowTax() != null ) {
            invoiceSettings.setShowTax( request.getShowTax() );
        }
        if ( request.getShowKhqr() != null ) {
            invoiceSettings.setShowKhqr( request.getShowKhqr() );
        }
        invoiceSettings.setPrinterName( request.getPrinterName() );
        invoiceSettings.setPrinterType( request.getPrinterType() );
        invoiceSettings.setPrinterAddress( request.getPrinterAddress() );
        invoiceSettings.setDefaultInvoiceFormat( request.getDefaultInvoiceFormat() );
        invoiceSettings.setDefaultReceiptFormat( request.getDefaultReceiptFormat() );

        return invoiceSettings;
    }

    @Override
    public SettingsDtos.InvoiceSettingsResponse toInvoiceResponse(InvoiceSettings entity) {
        if ( entity == null ) {
            return null;
        }

        SettingsDtos.InvoiceSettingsResponse invoiceSettingsResponse = new SettingsDtos.InvoiceSettingsResponse();

        invoiceSettingsResponse.setId( entity.getId() );
        invoiceSettingsResponse.setPrefix( entity.getPrefix() );
        invoiceSettingsResponse.setNextNumber( entity.getNextNumber() );
        invoiceSettingsResponse.setFooter( entity.getFooter() );
        invoiceSettingsResponse.setShowTax( entity.isShowTax() );
        invoiceSettingsResponse.setShowKhqr( entity.isShowKhqr() );
        invoiceSettingsResponse.setPrinterName( entity.getPrinterName() );
        invoiceSettingsResponse.setPrinterType( entity.getPrinterType() );
        invoiceSettingsResponse.setPrinterAddress( entity.getPrinterAddress() );
        invoiceSettingsResponse.setDefaultInvoiceFormat( entity.getDefaultInvoiceFormat() );
        invoiceSettingsResponse.setDefaultReceiptFormat( entity.getDefaultReceiptFormat() );

        return invoiceSettingsResponse;
    }
}
