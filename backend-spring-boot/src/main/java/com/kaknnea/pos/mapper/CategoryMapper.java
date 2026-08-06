package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.dto.CategoryDtos;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface CategoryMapper {
    @Mapping(target = "parentId", source = "parent.id")
    CategoryDtos.CategoryResponse toResponse(Category category);
}
