package com.kaknnea.pos.mapper;

import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.domain.ModifierGroup;
import com.kaknnea.pos.domain.ModifierOption;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.domain.ProductBundleComponent;
import com.kaknnea.pos.domain.ProductImage;
import com.kaknnea.pos.domain.Unit;
import com.kaknnea.pos.dto.ProductDto;
import com.kaknnea.pos.dto.ProductDtos;
import java.util.ArrayList;
import java.util.List;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-08-12T14:48:57+0700",
    comments = "version: 1.5.5.Final, compiler: Eclipse JDT (IDE) 3.46.100.v20260624-0231, environment: Java 21.0.11 (Eclipse Adoptium)"
)
@Component
public class ProductMapperImpl implements ProductMapper {

    @Override
    public ProductDtos.ProductResponse toResponse(Product product) {
        if ( product == null ) {
            return null;
        }

        ProductDtos.ProductResponse productResponse = new ProductDtos.ProductResponse();

        productResponse.setParentProductId( productParentProductId( product ) );
        productResponse.setParentProductNameEn( productParentProductNameEn( product ) );
        productResponse.setResolvedPrice( product.getResolvedPrice() );
        productResponse.setCategoryId( productCategoryId( product ) );
        productResponse.setCategoryNameEn( productCategoryNameEn( product ) );
        productResponse.setCategoryNameKm( productCategoryNameKm( product ) );
        productResponse.setSaleUnitId( productSaleUnitId( product ) );
        productResponse.setSaleUnitCode( productSaleUnitCode( product ) );
        productResponse.setPurchaseUnitId( productPurchaseUnitId( product ) );
        productResponse.setPurchaseUnitCode( productPurchaseUnitCode( product ) );
        productResponse.setStockUnitId( productStockUnitId( product ) );
        productResponse.setStockUnitCode( productStockUnitCode( product ) );
        productResponse.setBundleComponents( productBundleComponentListToProductBundleComponentResponseList( product.getBundleComponents() ) );
        productResponse.setImages( productImageListToProductImageResponseList( product.getImages() ) );
        productResponse.setModifierGroups( modifierGroupListToModifierGroupSummaryList( product.getModifierGroups() ) );
        productResponse.setId( product.getId() );
        productResponse.setSku( product.getSku() );
        productResponse.setBarcode( product.getBarcode() );
        productResponse.setNameEn( product.getNameEn() );
        productResponse.setNameKm( product.getNameKm() );
        productResponse.setImageUrl( product.getImageUrl() );
        productResponse.setDescription( product.getDescription() );
        productResponse.setCost( product.getCost() );
        productResponse.setPrice( product.getPrice() );
        productResponse.setActive( product.isActive() );
        productResponse.setSellable( product.isSellable() );
        productResponse.setPurchasable( product.isPurchasable() );
        productResponse.setTrackInventory( product.isTrackInventory() );
        productResponse.setProductType( product.getProductType() );
        productResponse.setLowStockThreshold( product.getLowStockThreshold() );
        productResponse.setVariantLabel( product.getVariantLabel() );
        productResponse.setBundleMode( product.getBundleMode() );

        return productResponse;
    }

    @Override
    public ProductDtos.ModifierGroupSummary toModifierGroupSummary(ModifierGroup group) {
        if ( group == null ) {
            return null;
        }

        ProductDtos.ModifierGroupSummary modifierGroupSummary = new ProductDtos.ModifierGroupSummary();

        modifierGroupSummary.setId( group.getId() );
        modifierGroupSummary.setNameEn( group.getNameEn() );
        modifierGroupSummary.setNameKm( group.getNameKm() );
        modifierGroupSummary.setRequired( group.isRequired() );
        modifierGroupSummary.setMultiSelect( group.isMultiSelect() );
        modifierGroupSummary.setOptions( modifierOptionListToModifierOptionSummaryList( group.getOptions() ) );

        return modifierGroupSummary;
    }

    @Override
    public ProductDtos.ModifierOptionSummary toModifierOptionSummary(ModifierOption option) {
        if ( option == null ) {
            return null;
        }

        ProductDtos.ModifierOptionSummary modifierOptionSummary = new ProductDtos.ModifierOptionSummary();

        modifierOptionSummary.setId( option.getId() );
        modifierOptionSummary.setNameEn( option.getNameEn() );
        modifierOptionSummary.setNameKm( option.getNameKm() );
        modifierOptionSummary.setPriceDelta( option.getPriceDelta() );

        return modifierOptionSummary;
    }

    @Override
    public ProductDtos.ProductImageResponse toImageResponse(ProductImage image) {
        if ( image == null ) {
            return null;
        }

        ProductDtos.ProductImageResponse productImageResponse = new ProductDtos.ProductImageResponse();

        productImageResponse.setPrimary( image.isPrimaryImage() );
        productImageResponse.setId( image.getId() );
        productImageResponse.setUrl( image.getUrl() );

        return productImageResponse;
    }

    @Override
    public ProductDtos.ProductBundleComponentResponse toBundleComponentResponse(ProductBundleComponent component) {
        if ( component == null ) {
            return null;
        }

        ProductDtos.ProductBundleComponentResponse productBundleComponentResponse = new ProductDtos.ProductBundleComponentResponse();

        productBundleComponentResponse.setComponentProductId( componentComponentProductId( component ) );
        productBundleComponentResponse.setComponentProductNameEn( componentComponentProductNameEn( component ) );
        productBundleComponentResponse.setComponentProductNameKm( componentComponentProductNameKm( component ) );
        productBundleComponentResponse.setComponentQuantity( component.getComponentQuantity() );
        productBundleComponentResponse.setId( component.getId() );

        return productBundleComponentResponse;
    }

    @Override
    public ProductDto toDto(Product product) {
        if ( product == null ) {
            return null;
        }

        ProductDto productDto = new ProductDto();

        productDto.setName( product.getName() );
        productDto.setDescription( product.getDescription() );
        if ( product.getPrice() != null ) {
            productDto.setPrice( product.getPrice().doubleValue() );
        }
        productDto.setId( product.getId() );

        return productDto;
    }

    private Long productParentProductId(Product product) {
        if ( product == null ) {
            return null;
        }
        Product parentProduct = product.getParentProduct();
        if ( parentProduct == null ) {
            return null;
        }
        Long id = parentProduct.getId();
        if ( id == null ) {
            return null;
        }
        return id;
    }

    private String productParentProductNameEn(Product product) {
        if ( product == null ) {
            return null;
        }
        Product parentProduct = product.getParentProduct();
        if ( parentProduct == null ) {
            return null;
        }
        String nameEn = parentProduct.getNameEn();
        if ( nameEn == null ) {
            return null;
        }
        return nameEn;
    }

    private Long productCategoryId(Product product) {
        if ( product == null ) {
            return null;
        }
        Category category = product.getCategory();
        if ( category == null ) {
            return null;
        }
        Long id = category.getId();
        if ( id == null ) {
            return null;
        }
        return id;
    }

    private String productCategoryNameEn(Product product) {
        if ( product == null ) {
            return null;
        }
        Category category = product.getCategory();
        if ( category == null ) {
            return null;
        }
        String nameEn = category.getNameEn();
        if ( nameEn == null ) {
            return null;
        }
        return nameEn;
    }

    private String productCategoryNameKm(Product product) {
        if ( product == null ) {
            return null;
        }
        Category category = product.getCategory();
        if ( category == null ) {
            return null;
        }
        String nameKm = category.getNameKm();
        if ( nameKm == null ) {
            return null;
        }
        return nameKm;
    }

    private Long productSaleUnitId(Product product) {
        if ( product == null ) {
            return null;
        }
        Unit saleUnit = product.getSaleUnit();
        if ( saleUnit == null ) {
            return null;
        }
        Long id = saleUnit.getId();
        if ( id == null ) {
            return null;
        }
        return id;
    }

    private String productSaleUnitCode(Product product) {
        if ( product == null ) {
            return null;
        }
        Unit saleUnit = product.getSaleUnit();
        if ( saleUnit == null ) {
            return null;
        }
        String code = saleUnit.getCode();
        if ( code == null ) {
            return null;
        }
        return code;
    }

    private Long productPurchaseUnitId(Product product) {
        if ( product == null ) {
            return null;
        }
        Unit purchaseUnit = product.getPurchaseUnit();
        if ( purchaseUnit == null ) {
            return null;
        }
        Long id = purchaseUnit.getId();
        if ( id == null ) {
            return null;
        }
        return id;
    }

    private String productPurchaseUnitCode(Product product) {
        if ( product == null ) {
            return null;
        }
        Unit purchaseUnit = product.getPurchaseUnit();
        if ( purchaseUnit == null ) {
            return null;
        }
        String code = purchaseUnit.getCode();
        if ( code == null ) {
            return null;
        }
        return code;
    }

    private Long productStockUnitId(Product product) {
        if ( product == null ) {
            return null;
        }
        Unit stockUnit = product.getStockUnit();
        if ( stockUnit == null ) {
            return null;
        }
        Long id = stockUnit.getId();
        if ( id == null ) {
            return null;
        }
        return id;
    }

    private String productStockUnitCode(Product product) {
        if ( product == null ) {
            return null;
        }
        Unit stockUnit = product.getStockUnit();
        if ( stockUnit == null ) {
            return null;
        }
        String code = stockUnit.getCode();
        if ( code == null ) {
            return null;
        }
        return code;
    }

    protected List<ProductDtos.ProductBundleComponentResponse> productBundleComponentListToProductBundleComponentResponseList(List<ProductBundleComponent> list) {
        if ( list == null ) {
            return null;
        }

        List<ProductDtos.ProductBundleComponentResponse> list1 = new ArrayList<ProductDtos.ProductBundleComponentResponse>( list.size() );
        for ( ProductBundleComponent productBundleComponent : list ) {
            list1.add( toBundleComponentResponse( productBundleComponent ) );
        }

        return list1;
    }

    protected List<ProductDtos.ProductImageResponse> productImageListToProductImageResponseList(List<ProductImage> list) {
        if ( list == null ) {
            return null;
        }

        List<ProductDtos.ProductImageResponse> list1 = new ArrayList<ProductDtos.ProductImageResponse>( list.size() );
        for ( ProductImage productImage : list ) {
            list1.add( toImageResponse( productImage ) );
        }

        return list1;
    }

    protected List<ProductDtos.ModifierGroupSummary> modifierGroupListToModifierGroupSummaryList(List<ModifierGroup> list) {
        if ( list == null ) {
            return null;
        }

        List<ProductDtos.ModifierGroupSummary> list1 = new ArrayList<ProductDtos.ModifierGroupSummary>( list.size() );
        for ( ModifierGroup modifierGroup : list ) {
            list1.add( toModifierGroupSummary( modifierGroup ) );
        }

        return list1;
    }

    protected List<ProductDtos.ModifierOptionSummary> modifierOptionListToModifierOptionSummaryList(List<ModifierOption> list) {
        if ( list == null ) {
            return null;
        }

        List<ProductDtos.ModifierOptionSummary> list1 = new ArrayList<ProductDtos.ModifierOptionSummary>( list.size() );
        for ( ModifierOption modifierOption : list ) {
            list1.add( toModifierOptionSummary( modifierOption ) );
        }

        return list1;
    }

    private Long componentComponentProductId(ProductBundleComponent productBundleComponent) {
        if ( productBundleComponent == null ) {
            return null;
        }
        Product componentProduct = productBundleComponent.getComponentProduct();
        if ( componentProduct == null ) {
            return null;
        }
        Long id = componentProduct.getId();
        if ( id == null ) {
            return null;
        }
        return id;
    }

    private String componentComponentProductNameEn(ProductBundleComponent productBundleComponent) {
        if ( productBundleComponent == null ) {
            return null;
        }
        Product componentProduct = productBundleComponent.getComponentProduct();
        if ( componentProduct == null ) {
            return null;
        }
        String nameEn = componentProduct.getNameEn();
        if ( nameEn == null ) {
            return null;
        }
        return nameEn;
    }

    private String componentComponentProductNameKm(ProductBundleComponent productBundleComponent) {
        if ( productBundleComponent == null ) {
            return null;
        }
        Product componentProduct = productBundleComponent.getComponentProduct();
        if ( componentProduct == null ) {
            return null;
        }
        String nameKm = componentProduct.getNameKm();
        if ( nameKm == null ) {
            return null;
        }
        return nameKm;
    }
}
