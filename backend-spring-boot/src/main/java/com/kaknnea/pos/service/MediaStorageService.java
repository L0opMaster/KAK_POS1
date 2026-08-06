package com.kaknnea.pos.service;

import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Set;
import java.util.UUID;

@Service
public class MediaStorageService {
    private static final long MAX_FILE_SIZE = 5L * 1024 * 1024;
    private static final Set<String> ALLOWED_TYPES = Set.of("image/jpeg", "image/png", "image/webp", "image/gif");

    private final Path uploadRoot;

    public MediaStorageService() {
        String configured = System.getenv("APP_UPLOAD_DIR");
        if (configured == null || configured.isBlank()) {
            configured = "uploads";
        }
        this.uploadRoot = Path.of(configured).toAbsolutePath().normalize();
    }

    public String storeImage(MultipartFile file) throws IOException {
        validate(file);
        Files.createDirectories(uploadRoot.resolve("images"));

        String extension = extension(file.getOriginalFilename(), file.getContentType());
        String filename = UUID.randomUUID() + extension;
        Path destination = uploadRoot.resolve("images").resolve(filename).normalize();

        try (InputStream inputStream = file.getInputStream()) {
            Files.copy(inputStream, destination, StandardCopyOption.REPLACE_EXISTING);
        }

        return "images/" + filename;
    }

    public Path getUploadRoot() {
        return uploadRoot;
    }

    private void validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Image file is required");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException("Image must be 5MB or smaller");
        }
        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_TYPES.contains(contentType.toLowerCase())) {
            throw new IllegalArgumentException("Only JPG, PNG, WEBP, and GIF images are supported");
        }
    }

    private String extension(String originalFilename, String contentType) {
        String ext = StringUtils.getFilenameExtension(originalFilename);
        if (ext != null && !ext.isBlank()) {
            return "." + ext.toLowerCase();
        }
        return switch (contentType == null ? "" : contentType.toLowerCase()) {
            case "image/jpeg" -> ".jpg";
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            case "image/gif" -> ".gif";
            default -> ".img";
        };
    }
}
