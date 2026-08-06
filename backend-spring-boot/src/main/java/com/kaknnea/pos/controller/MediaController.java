package com.kaknnea.pos.controller;

import com.kaknnea.pos.service.MediaStorageService;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/api/media")
public class MediaController {
    private final MediaStorageService mediaStorageService;

    public MediaController(MediaStorageService mediaStorageService) {
        this.mediaStorageService = mediaStorageService;
    }

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("isAuthenticated()")
    public Map<String, String> upload(@RequestPart("file") MultipartFile file) throws IOException {
        String relativePath = mediaStorageService.storeImage(file);
        String url = ServletUriComponentsBuilder.fromCurrentContextPath()
                .path("/media/")
                .path(relativePath)
                .toUriString();
        return Map.of("url", url, "path", relativePath);
    }
}
