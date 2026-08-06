package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.ModifierGroup;
import com.kaknnea.pos.domain.ModifierOption;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.dto.ModifierDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.mapper.ModifierMapper;
import com.kaknnea.pos.repository.ModifierGroupRepository;
import com.kaknnea.pos.repository.ModifierOptionRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.SecurityUtil;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ModifierService {
    private final ModifierGroupRepository groupRepository;
    private final ModifierOptionRepository optionRepository;
    private final ProductRepository productRepository;
    private final ModifierMapper mapper;
    private final AuditService auditService;
    private final UserRepository userRepository;

    public ModifierService(ModifierGroupRepository groupRepository,
            ModifierOptionRepository optionRepository,
            ProductRepository productRepository,
            ModifierMapper mapper,
            AuditService auditService,
            UserRepository userRepository) {
        this.groupRepository = groupRepository;
        this.optionRepository = optionRepository;
        this.productRepository = productRepository;
        this.mapper = mapper;
        this.auditService = auditService;
        this.userRepository = userRepository;
    }

    public List<ModifierDtos.ModifierGroupResponse> listGroups() {
        List<ModifierGroup> groups = groupRepository.findAllByOrderByDisplayOrderAsc();
        groups.forEach(group -> group.getOptions().sort(Comparator.comparingInt(ModifierOption::getDisplayOrder)));
        return groups.stream()
                .map(mapper::toGroupResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public ModifierDtos.ModifierGroupResponse createGroup(ModifierDtos.ModifierGroupRequest request) {
        ModifierGroup group = new ModifierGroup();
        applyGroup(group, request);
        ModifierGroup saved = groupRepository.save(group);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "MODIFIER_GROUP_CREATE", "ModifierGroup", String.valueOf(saved.getId()), null, saved);
        return mapper.toGroupResponse(saved);
    }

    @Transactional
    public ModifierDtos.ModifierGroupResponse updateGroup(Long id, ModifierDtos.ModifierGroupRequest request) {
        ModifierGroup group = groupRepository.findById(id)
                .orElseThrow(() -> new ApiException("Modifier group not found"));
        ModifierGroup before = new ModifierGroup();
        before.setId(group.getId());
        before.setNameEn(group.getNameEn());
        before.setNameKm(group.getNameKm());
        before.setRequired(group.isRequired());
        before.setMultiSelect(group.isMultiSelect());
        before.setActive(group.isActive());
        before.setDisplayOrder(group.getDisplayOrder());
        applyGroup(group, request);
        ModifierGroup saved = groupRepository.save(group);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "MODIFIER_GROUP_UPDATE", "ModifierGroup", String.valueOf(saved.getId()), before, saved);
        return mapper.toGroupResponse(saved);
    }

    @Transactional
    public void deleteGroup(Long id) {
        ModifierGroup group = groupRepository.findById(id)
                .orElseThrow(() -> new ApiException("Modifier group not found"));
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "MODIFIER_GROUP_DELETE", "ModifierGroup", String.valueOf(group.getId()), group, null);
        groupRepository.delete(group);
    }

    @Transactional
    public ModifierDtos.ModifierOptionResponse addOption(Long groupId, ModifierDtos.ModifierOptionRequest request) {
        ModifierGroup group = groupRepository.findById(groupId)
                .orElseThrow(() -> new ApiException("Modifier group not found"));
        ModifierOption option = new ModifierOption();
        option.setGroup(group);
        applyOption(option, request);
        ModifierOption saved = optionRepository.save(option);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "MODIFIER_OPTION_CREATE", "ModifierOption", String.valueOf(saved.getId()), null, saved);
        return mapper.toOptionResponse(saved);
    }

    @Transactional
    public ModifierDtos.ModifierOptionResponse updateOption(Long id, ModifierDtos.ModifierOptionRequest request) {
        ModifierOption option = optionRepository.findById(id)
                .orElseThrow(() -> new ApiException("Modifier option not found"));
        ModifierOption before = new ModifierOption();
        before.setId(option.getId());
        before.setNameEn(option.getNameEn());
        before.setNameKm(option.getNameKm());
        before.setPriceDelta(option.getPriceDelta());
        before.setActive(option.isActive());
        before.setDisplayOrder(option.getDisplayOrder());
        applyOption(option, request);
        ModifierOption saved = optionRepository.save(option);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "MODIFIER_OPTION_UPDATE", "ModifierOption", String.valueOf(saved.getId()), before,
                saved);
        return mapper.toOptionResponse(saved);
    }

    @Transactional
    public void deleteOption(Long id) {
        ModifierOption option = optionRepository.findById(id)
                .orElseThrow(() -> new ApiException("Modifier option not found"));
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "MODIFIER_OPTION_DELETE", "ModifierOption", String.valueOf(option.getId()), option,
                null);
        optionRepository.delete(option);
    }

    public List<Long> getGroupProductIds(Long groupId) {
        return productRepository.findAllByModifierGroups_Id(groupId)
                .stream()
                .map(Product::getId)
                .collect(Collectors.toList());
    }

    @Transactional
    public void updateGroupProducts(Long groupId, List<Long> productIds) {
        ModifierGroup group = groupRepository.findById(groupId)
                .orElseThrow(() -> new ApiException("Modifier group not found"));
        List<Product> current = productRepository.findAllByModifierGroups_Id(groupId);
        for (Product product : current) {
            product.getModifierGroups().remove(group);
        }
        productRepository.saveAll(current);

        if (productIds == null || productIds.isEmpty()) {
            return;
        }
        List<Product> selected = productRepository.findAllById(productIds);
        for (Product product : selected) {
            if (!product.getModifierGroups().contains(group)) {
                product.getModifierGroups().add(group);
            }
        }
        productRepository.saveAll(selected);
    }

    @Transactional(readOnly = true)
    public List<ModifierDtos.ProductModifiersResponse> getProductModifiers(Long productId) {
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new ApiException("Product not found"));
        return product.getModifierGroups().stream()
                .sorted(Comparator.comparingInt(ModifierGroup::getDisplayOrder))
                .map(group -> {
                    ModifierDtos.ProductModifiersResponse resp = mapper.toProductModifiersResponse(group);
                    List<ModifierDtos.ModifierOptionResponse> options = group.getOptions().stream()
                            .sorted(Comparator.comparingInt(ModifierOption::getDisplayOrder))
                            .map(mapper::toOptionResponse)
                            .collect(Collectors.toList());
                    resp.setOptions(options);
                    return resp;
                })
                .collect(Collectors.toList());
    }

    private void applyGroup(ModifierGroup group, ModifierDtos.ModifierGroupRequest request) {
        group.setNameEn(request.getNameEn());
        group.setNameKm(request.getNameKm());
        group.setRequired(request.isRequired());
        group.setMultiSelect(request.isMultiSelect());
        group.setActive(request.isActive());
        group.setDisplayOrder(request.getDisplayOrder());
    }

    private void applyOption(ModifierOption option, ModifierDtos.ModifierOptionRequest request) {
        option.setNameEn(request.getNameEn());
        option.setNameKm(request.getNameKm());
        option.setPriceDelta(request.getPriceDelta());
        option.setActive(request.isActive());
        option.setDisplayOrder(request.getDisplayOrder());
    }
}
