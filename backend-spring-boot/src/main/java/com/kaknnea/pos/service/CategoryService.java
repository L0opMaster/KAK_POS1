package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Category;
import com.kaknnea.pos.dto.CategoryDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.mapper.CategoryMapper;
import com.kaknnea.pos.repository.CategoryRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.SecurityUtil;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class CategoryService {
    private final CategoryRepository categoryRepository;
    private final CategoryMapper categoryMapper;
    private final AuditService auditService;
    private final UserRepository userRepository;

    public CategoryService(CategoryRepository categoryRepository, CategoryMapper categoryMapper,
                           AuditService auditService, UserRepository userRepository) {
        this.categoryRepository = categoryRepository;
        this.categoryMapper = categoryMapper;
        this.auditService = auditService;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public List<CategoryDtos.CategoryResponse> list() {
        return categoryRepository.findAll().stream().map(categoryMapper::toResponse).collect(Collectors.toList());
    }

    @Transactional
    public CategoryDtos.CategoryResponse create(CategoryDtos.CategoryRequest request) {
        Category category = new Category();
        category.setNameEn(request.getNameEn());
        category.setNameKm(request.getNameKm());
        category.setActive(request.isActive());
        if (request.getParentId() != null) {
            Category parent = categoryRepository.findById(request.getParentId())
                    .orElseThrow(() -> new ApiException("Parent category not found"));
            category.setParent(parent);
        }
        Category saved = categoryRepository.save(category);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "CATEGORY_CREATE", "Category", String.valueOf(saved.getId()), null, saved);
        return categoryMapper.toResponse(saved);
    }

    @Transactional
    public CategoryDtos.CategoryResponse update(Long id, CategoryDtos.CategoryRequest request) {
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> new ApiException("Category not found"));
        Category before = new Category();
        before.setId(category.getId());
        before.setNameEn(category.getNameEn());
        before.setNameKm(category.getNameKm());
        before.setActive(category.isActive());
        category.setNameEn(request.getNameEn());
        category.setNameKm(request.getNameKm());
        category.setActive(request.isActive());
        if (request.getParentId() != null) {
            Category parent = categoryRepository.findById(request.getParentId())
                    .orElseThrow(() -> new ApiException("Parent category not found"));
            category.setParent(parent);
        } else {
            category.setParent(null);
        }
        Category saved = categoryRepository.save(category);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "CATEGORY_UPDATE", "Category", String.valueOf(saved.getId()), before, saved);
        return categoryMapper.toResponse(saved);
    }
}
