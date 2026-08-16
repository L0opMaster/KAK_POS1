package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.ModifierGroup;
import com.kaknnea.pos.domain.ModifierOption;
import com.kaknnea.pos.dto.ModifierDtos;
import java.util.ArrayList;
import java.util.List;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-08-16T12:54:45+0700",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 17.0.19 (Ubuntu)"
)
@Component
public class ModifierMapperImpl implements ModifierMapper {

    @Override
    public ModifierDtos.ModifierGroupResponse toGroupResponse(ModifierGroup group) {
        if ( group == null ) {
            return null;
        }

        ModifierDtos.ModifierGroupResponse modifierGroupResponse = new ModifierDtos.ModifierGroupResponse();

        modifierGroupResponse.setId( group.getId() );
        modifierGroupResponse.setNameEn( group.getNameEn() );
        modifierGroupResponse.setNameKm( group.getNameKm() );
        modifierGroupResponse.setRequired( group.isRequired() );
        modifierGroupResponse.setMultiSelect( group.isMultiSelect() );
        modifierGroupResponse.setActive( group.isActive() );
        modifierGroupResponse.setDisplayOrder( group.getDisplayOrder() );
        modifierGroupResponse.setOptions( modifierOptionListToModifierOptionResponseList( group.getOptions() ) );

        return modifierGroupResponse;
    }

    @Override
    public ModifierDtos.ModifierOptionResponse toOptionResponse(ModifierOption option) {
        if ( option == null ) {
            return null;
        }

        ModifierDtos.ModifierOptionResponse modifierOptionResponse = new ModifierDtos.ModifierOptionResponse();

        modifierOptionResponse.setId( option.getId() );
        modifierOptionResponse.setNameEn( option.getNameEn() );
        modifierOptionResponse.setNameKm( option.getNameKm() );
        modifierOptionResponse.setPriceDelta( option.getPriceDelta() );
        modifierOptionResponse.setActive( option.isActive() );
        modifierOptionResponse.setDisplayOrder( option.getDisplayOrder() );

        return modifierOptionResponse;
    }

    @Override
    public ModifierDtos.ProductModifiersResponse toProductModifiersResponse(ModifierGroup group) {
        if ( group == null ) {
            return null;
        }

        ModifierDtos.ProductModifiersResponse productModifiersResponse = new ModifierDtos.ProductModifiersResponse();

        productModifiersResponse.setGroupId( group.getId() );
        productModifiersResponse.setGroupNameEn( group.getNameEn() );
        productModifiersResponse.setGroupNameKm( group.getNameKm() );
        productModifiersResponse.setRequired( group.isRequired() );
        productModifiersResponse.setMultiSelect( group.isMultiSelect() );
        productModifiersResponse.setOptions( modifierOptionListToModifierOptionResponseList( group.getOptions() ) );

        return productModifiersResponse;
    }

    protected List<ModifierDtos.ModifierOptionResponse> modifierOptionListToModifierOptionResponseList(List<ModifierOption> list) {
        if ( list == null ) {
            return null;
        }

        List<ModifierDtos.ModifierOptionResponse> list1 = new ArrayList<ModifierDtos.ModifierOptionResponse>( list.size() );
        for ( ModifierOption modifierOption : list ) {
            list1.add( toOptionResponse( modifierOption ) );
        }

        return list1;
    }
}
