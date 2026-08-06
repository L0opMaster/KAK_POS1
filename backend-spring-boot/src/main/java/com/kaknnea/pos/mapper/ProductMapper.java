package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.ModifierGroup;
import com.kaknnea.pos.domain.ModifierOption;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.ProductBundleComponent;
import com.kaknnea.pos.domain.ProductImage;
import com.kaknnea.pos.dto.ProductDtos;
import com.kaknnea.pos.dto.ProductDto;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Mappings;
import org.mapstruct.ReportingPolicy;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface ProductMapper {
    @Mappings({
        @Mapping(target = "parentProductId", source = "parentProduct.id"),
        @Mapping(target = "parentProductNameEn", source = "parentProduct.nameEn"),
        @Mapping(target = "resolvedPrice", source = "resolvedPrice"),
        @Mapping(target = "categoryId", source = "category.id"),
        @Mapping(target = "categoryNameEn", source = "category.nameEn"),
        @Mapping(target = "categoryNameKm", source = "category.nameKm"),
        @Mapping(target = "saleUnitId", source = "saleUnit.id"),
        @Mapping(target = "saleUnitCode", source = "saleUnit.code"),
        @Mapping(target = "purchaseUnitId", source = "purchaseUnit.id"),
        @Mapping(target = "purchaseUnitCode", source = "purchaseUnit.code"),
        @Mapping(target = "stockUnitId", source = "stockUnit.id"),
        @Mapping(target = "stockUnitCode", source = "stockUnit.code"),
        @Mapping(target = "bundleComponents", source = "bundleComponents"),
        @Mapping(target = "images", source = "images"),
        @Mapping(target = "modifierGroups", source = "modifierGroups")
    })
    ProductDtos.ProductResponse toResponse(Product product);

    ProductDtos.ModifierGroupSummary toModifierGroupSummary(ModifierGroup group);

    ProductDtos.ModifierOptionSummary toModifierOptionSummary(ModifierOption option);

    @Mapping(target = "primary", source = "primaryImage")
    ProductDtos.ProductImageResponse toImageResponse(ProductImage image);

    @Mappings({
        @Mapping(target = "componentProductId", source = "componentProduct.id"),
        @Mapping(target = "componentProductNameEn", source = "componentProduct.nameEn"),
        @Mapping(target = "componentProductNameKm", source = "componentProduct.nameKm"),
        @Mapping(target = "componentQuantity", source = "componentQuantity")
    })
    ProductDtos.ProductBundleComponentResponse toBundleComponentResponse(ProductBundleComponent component);

    @Mapping(target = "name", source = "product.name")
    @Mapping(target = "description", source = "product.description")
    @Mapping(target = "price", source = "product.price")
    ProductDto toDto(Product product);
}
