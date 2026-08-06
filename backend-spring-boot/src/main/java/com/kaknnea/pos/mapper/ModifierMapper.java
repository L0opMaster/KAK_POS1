package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.ModifierGroup;
import com.kaknnea.pos.domain.ModifierOption;
import com.kaknnea.pos.dto.ModifierDtos;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface ModifierMapper {
    ModifierDtos.ModifierGroupResponse toGroupResponse(ModifierGroup group);

    ModifierDtos.ModifierOptionResponse toOptionResponse(ModifierOption option);

    @Mapping(target = "groupId", source = "id")
    @Mapping(target = "groupNameEn", source = "nameEn")
    @Mapping(target = "groupNameKm", source = "nameKm")
    ModifierDtos.ProductModifiersResponse toProductModifiersResponse(ModifierGroup group);
}
