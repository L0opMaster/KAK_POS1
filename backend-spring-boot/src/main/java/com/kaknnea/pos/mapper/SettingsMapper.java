package com.kaknnea.pos.mapper;

// MapStruct mapper for converting between entities and DTOs
import com.kaknnea.pos.domain.BusinessSettings;
import com.kaknnea.pos.domain.InvoiceSettings;
import com.kaknnea.pos.dto.SettingsDtos;
import com.kaknnea.pos.dto.SettingsDtos.BusinessSettingsRequest;
import com.kaknnea.pos.dto.SettingsDtos.BusinessSettingsResponse;
import com.kaknnea.pos.dto.SettingsDtos.InvoiceSettingsRequest;
import com.kaknnea.pos.dto.SettingsDtos.InvoiceSettingsResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface SettingsMapper {
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    @Mapping(target = "posLayoutConfig", ignore = true)
    @Mapping(target = "openTicketConfig", ignore = true)
    BusinessSettings toBusinessEntity(BusinessSettingsRequest request);

    BusinessSettingsResponse toBusinessResponse(BusinessSettings entity);

    @Mapping(target = "id", ignore = true)
    InvoiceSettings toInvoiceEntity(SettingsDtos.InvoiceSettingsRequest request);

    SettingsDtos.InvoiceSettingsResponse toInvoiceResponse(InvoiceSettings entity);
}
