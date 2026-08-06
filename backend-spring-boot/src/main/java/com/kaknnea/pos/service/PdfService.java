package com.kaknnea.pos.service;

import com.openhtmltopdf.pdfboxout.PdfRendererBuilder;
import com.openhtmltopdf.outputdevice.helper.BaseRendererBuilder;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.util.List;

@Service
public class PdfService {
    public byte[] renderHtmlToPdf(String html) {
        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            PdfRendererBuilder builder = new PdfRendererBuilder();
            registerOptionalFont(builder);
            builder.withHtmlContent(html, null);
            builder.toStream(out);
            builder.run();
            return out.toByteArray();
        } catch (Exception e) {
            throw new RuntimeException("Failed to render PDF", e);
        }
    }

    private void registerOptionalFont(PdfRendererBuilder builder) {
        String fontPath = System.getenv("PDF_KHMER_FONT_PATH");
        if (fontPath == null || fontPath.isBlank()) {
            registerDefaultKhmerFonts(builder);
            return;
        }

        File fontFile = new File(fontPath);
        if (!fontFile.exists()) {
            registerDefaultKhmerFonts(builder);
            return;
        }

        if (fontFile.isDirectory()) {
            registerFontIfExists(builder, new File(fontFile, "NotoSansKhmer-Regular.ttf"), 400);
            registerFontIfExists(builder, new File(fontFile, "NotoSansKhmer-Medium.ttf"), 500);
            registerFontIfExists(builder, new File(fontFile, "NotoSansKhmer-SemiBold.ttf"), 600);
            registerFontIfExists(builder, new File(fontFile, "NotoSansKhmer-Bold.ttf"), 700);
            return;
        }

        registerFont(builder, fontFile, 400);
    }

    private void registerDefaultKhmerFonts(PdfRendererBuilder builder) {
        registerClasspathFont(builder, "/fonts/NotoSansKhmer-Regular.ttf", 400);
        registerClasspathFont(builder, "/fonts/NotoSansKhmer-Medium.ttf", 500);
        registerClasspathFont(builder, "/fonts/NotoSansKhmer-SemiBold.ttf", 600);
        registerClasspathFont(builder, "/fonts/NotoSansKhmer-Bold.ttf", 700);
    }

    private void registerFontIfExists(PdfRendererBuilder builder, File fontFile, int weight) {
        if (!fontFile.exists()) {
            return;
        }
        registerFont(builder, fontFile, weight);
    }

    private void registerFont(PdfRendererBuilder builder, File fontFile, int weight) {
        for (String family : List.of("Noto Sans Khmer", "KhmerFallback")) {
            builder.useFont(fontFile, family, weight, BaseRendererBuilder.FontStyle.NORMAL, true);
        }
    }

    private void registerClasspathFont(PdfRendererBuilder builder, String resourcePath, int weight) {
        try (InputStream in = PdfService.class.getResourceAsStream(resourcePath)) {
            if (in == null) {
                return;
            }
            File temp = File.createTempFile("khmer-font-", ".ttf");
            temp.deleteOnExit();
            Files.copy(in, temp.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            registerFont(builder, temp, weight);
        } catch (IOException ignored) {
            // Ignore font loading errors and fall back to system fonts
        }
    }
}
