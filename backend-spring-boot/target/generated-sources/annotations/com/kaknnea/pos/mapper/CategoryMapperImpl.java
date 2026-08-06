package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.dto.CategoryDtos;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-08-05T14:02:57+0700",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 17.0.19 (Ubuntu)"
)
@Component
public class CategoryMapperImpl implements CategoryMapper {

    @Override
    public CategoryDtos.CategoryResponse toResponse(Category category) {
        if ( category == null ) {
            return null;
        }

        CategoryDtos.CategoryResponse categoryResponse = new CategoryDtos.CategoryResponse();

        categoryResponse.setParentId( categoryParentId( category ) );
        categoryResponse.setId( category.getId() );
        categoryResponse.setNameEn( category.getNameEn() );
        categoryResponse.setNameKm( category.getNameKm() );
        categoryResponse.setActive( category.isActive() );

        return categoryResponse;
    }

    private Long categoryParentId(Category category) {
        if ( category == null ) {
            return null;
        }
        Category parent = category.getParent();
        if ( parent == null ) {
            return null;
        }
        Long id = parent.getId();
        if ( id == null ) {
            return null;
        }
        return id;
    }
}
