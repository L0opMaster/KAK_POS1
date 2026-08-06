package com.kaknnea.pos.service;

import com.kaknnea.pos.dto.ReceiptDtos;
import com.kaknnea.pos.dto.SaleDtos;
import com.kaknnea.pos.dto.PurchasingWorkflowDtos;
import com.kaknnea.pos.repository.BusinessSettingsRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import jakarta.mail.internet.MimeMessage;
import jakarta.mail.util.ByteArrayDataSource;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;

/**
 * Email service for sending invoices, receipts, and purchase orders.
 * Configure spring.mail.* properties in application.yml for SMTP integration.
 */
@Service
public class EmailService {
    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    private final BusinessSettingsRepository businessSettingsRepository;
    private final JavaMailSender mailSender;

    public EmailService(BusinessSettingsRepository businessSettingsRepository,
                        JavaMailSender mailSender) {
        this.businessSettingsRepository = businessSettingsRepository;
        this.mailSender = mailSender;
    }

    private String resolveFromEmail() {
        return System.getProperty("app.mail.from",
               System.getenv("MAIL_FROM") != null ? System.getenv("MAIL_FROM")
               : "noreply@kaknnea.com");
    }

    public void sendReceipt(String recipientEmail, String recipientName,
            ReceiptDtos.ReceiptResponse receipt, byte[] pdfAttachment) {
        var settings = businessSettingsRepository.findAll().stream().findFirst().orElse(null);
        String businessName = settings != null ? settings.getBusinessName() : "KAKNNEA POS";
        String fromEmail = resolveFromEmail();

        String subject = String.format("Invoice %s from %s",
                receipt.getSaleNumber() != null ? receipt.getSaleNumber() : "#" + receipt.getSaleId(),
                businessName);

        String htmlBody = buildInvoiceEmailHtml(receipt, businessName, recipientName);

        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, StandardCharsets.UTF_8.name());
            helper.setFrom(fromEmail);
            helper.setTo(recipientEmail);
            helper.setSubject(subject);
            helper.setText(htmlBody, true);

            if (pdfAttachment != null && pdfAttachment.length > 0) {
                String filename = String.format("invoice-%s.pdf",
                        receipt.getSaleNumber() != null ? receipt.getSaleNumber() : receipt.getSaleId());
                helper.addAttachment(filename, () -> new java.io.ByteArrayInputStream(pdfAttachment),
                        "application/pdf");
            }

            mailSender.send(message);
            log.info("Email sent successfully: saleId={}, to={} ({})", receipt.getSaleId(), recipientName, recipientEmail);
        } catch (Exception e) {
            log.error("Failed to send email: saleId={}, to={}, error={}",
                    receipt.getSaleId(), recipientEmail, e.getMessage(), e);
            throw new RuntimeException("Failed to send email: " + e.getMessage(), e);
        }
    }

    public void sendPurchaseOrder(String recipientEmail, String recipientName,
            PurchasingWorkflowDtos.PurchaseOrderResponse purchaseOrder) {
        var settings = businessSettingsRepository.findAll().stream().findFirst().orElse(null);
        String businessName = settings != null ? settings.getBusinessName() : "KAKNNEA POS";
        String fromEmail = resolveFromEmail();

        String poNumber = purchaseOrder.getReferenceNumber() != null
                ? purchaseOrder.getReferenceNumber()
                : "PO#" + purchaseOrder.getId();
        String subject = String.format("Purchase Order %s from %s", poNumber, businessName);

        String htmlBody = String.format("""
            <html><body style="font-family:Arial,sans-serif;padding:20px;">
            <h2>Purchase Order %s</h2>
            <p>Dear <strong>%s</strong>,</p>
            <p>Please find the attached purchase order from <strong>%s</strong>.</p>
            <table style="border-collapse:collapse;width:100%%;margin:16px 0;">
                <tr><td style="padding:6px 8px;background:#f3f4f6;font-weight:700;">PO#</td>
                    <td style="padding:6px 8px;">%s</td></tr>
                <tr><td style="padding:6px 8px;background:#f3f4f6;font-weight:700;">Total</td>
                    <td style="padding:6px 8px;">$%s</td></tr>
                <tr><td style="padding:6px 8px;background:#f3f4f6;font-weight:700;">Status</td>
                    <td style="padding:6px 8px;">%s</td></tr>
            </table>
            <p style="color:#6b7280;font-size:12px;">This is an automated message from %s.</p>
            </body></html>
            """,
            poNumber, recipientName, businessName,
            poNumber,
            purchaseOrder.getTotalAmount() != null ? purchaseOrder.getTotalAmount().toPlainString() : "0.00",
            purchaseOrder.getStatus(),
            businessName);

        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, StandardCharsets.UTF_8.name());
            helper.setFrom(fromEmail);
            helper.setTo(recipientEmail);
            helper.setSubject(subject);
            helper.setText(htmlBody, true);
            mailSender.send(message);
            log.info("Purchase order email sent: poId={}, to={}", purchaseOrder.getId(), recipientEmail);
        } catch (Exception e) {
            log.error("Failed to send purchase order email: poId={}, to={}, error={}",
                    purchaseOrder.getId(), recipientEmail, e.getMessage(), e);
            throw new RuntimeException("Failed to send email: " + e.getMessage(), e);
        }
    }

    public void sendEstimate(String recipientEmail, String recipientName,
            SaleDtos.SaleResponse estimate, byte[] pdf) {
        var settings = businessSettingsRepository.findAll().stream().findFirst().orElse(null);
        String businessName = settings != null ? settings.getBusinessName() : "KAKNNEA POS";
        String fromEmail = resolveFromEmail();

        String estimateNumber = estimate.getInvoiceNumber() != null
                ? estimate.getInvoiceNumber()
                : "EST#" + estimate.getId();
        String subject = String.format("Estimate %s from %s", estimateNumber, businessName);

        String htmlBody = String.format("""
            <html><body style="font-family:Arial,sans-serif;padding:20px;">
            <h2>Estimate %s</h2>
            <p>Dear <strong>%s</strong>,</p>
            <p>Please find attached an estimate from <strong>%s</strong>.</p>
            <table style="border-collapse:collapse;width:100%%;margin:16px 0;">
                <tr><td style="padding:6px 8px;background:#f3f4f6;font-weight:700;">Estimate#</td>
                    <td style="padding:6px 8px;">%s</td></tr>
                <tr><td style="padding:6px 8px;background:#f3f4f6;font-weight:700;">Total</td>
                    <td style="padding:6px 8px;">$%s</td></tr>
                <tr><td style="padding:6px 8px;background:#f3f4f6;font-weight:700;">Status</td>
                    <td style="padding:6px 8px;">%s</td></tr>
            </table>
            <p style="color:#6b7280;font-size:12px;">This is an estimate, not an invoice. Please review and confirm.</p>
            <p style="color:#6b7280;font-size:12px;">This is an automated message from %s.</p>
            </body></html>
            """,
            estimateNumber, recipientName, businessName,
            estimateNumber,
            estimate.getGrandTotal() != null ? estimate.getGrandTotal().toPlainString() : "0.00",
            estimate.getStatus(),
            businessName);

        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, StandardCharsets.UTF_8.name());
            helper.setFrom(fromEmail);
            helper.setTo(recipientEmail);
            helper.setSubject(subject);
            helper.setText(htmlBody, true);
            if (pdf != null) {
                helper.addAttachment("estimate-" + estimateNumber + ".pdf", new ByteArrayDataSource(pdf, "application/pdf"));
            }
            mailSender.send(message);
            log.info("Estimate email sent: estimateId={}, to={}", estimate.getId(), recipientEmail);
        } catch (Exception e) {
            log.error("Failed to send estimate email: estimateId={}, to={}, error={}",
                    estimate.getId(), recipientEmail, e.getMessage(), e);
            throw new RuntimeException("Failed to send email: " + e.getMessage(), e);
        }
    }

    private String buildInvoiceEmailHtml(ReceiptDtos.ReceiptResponse receipt, String businessName, String recipientName) {
        String saleNumber = receipt.getSaleNumber() != null ? receipt.getSaleNumber() : "#" + receipt.getSaleId();
        String currency = receipt.getCurrency() != null ? receipt.getCurrency() : "KHR";
        String symbol = "KHR".equals(currency) ? "\u17DB" : "$";
        BigDecimal total = receipt.getTotal() != null ? receipt.getTotal() : BigDecimal.ZERO;
        BigDecimal paid = receipt.getPaidAmount() != null ? receipt.getPaidAmount() : BigDecimal.ZERO;
        BigDecimal balance = total.subtract(paid).max(BigDecimal.ZERO);
        boolean isPaid = paid.compareTo(BigDecimal.ZERO) > 0 && paid.compareTo(total) >= 0;
        String statusLabel = isPaid ? "Paid \u2705" : "Outstanding: " + symbol + " " + balance.toPlainString();

        StringBuilder linesHtml = new StringBuilder();
        if (receipt.getLines() != null) {
            for (var line : receipt.getLines()) {
                String name = line.getNameEn() != null ? line.getNameEn() : "Item";
                BigDecimal qty = line.getQty() != null ? line.getQty() : BigDecimal.ONE;
                BigDecimal price = line.getUnitPrice() != null ? line.getUnitPrice() : BigDecimal.ZERO;
                BigDecimal lineTotal = line.getLineTotal() != null ? line.getLineTotal() : BigDecimal.ZERO;
                String modifierSummary = line.getModifierSummary();
                String modifierHtml = (modifierSummary != null && !modifierSummary.isBlank())
                        ? "<div style=\"font-size:11px;color:#6b7280;font-style:italic;\">" + modifierSummary + "</div>"
                        : "";
                linesHtml.append(String.format("""
                    <tr><td style="padding:6px 8px;border-bottom:1px solid #e5e7eb;">%s%s</td>
                        <td style="padding:6px 8px;border-bottom:1px solid #e5e7eb;text-align:center;">%s</td>
                        <td style="padding:6px 8px;border-bottom:1px solid #e5e7eb;text-align:right;">%s %s</td></tr>
                    """,
                    name, modifierHtml, qty.toPlainString(), symbol, lineTotal.toPlainString()));
            }
        }

        return String.format("""
            <html><body style="font-family:Arial,'Noto Sans Khmer',sans-serif;padding:0;margin:0;background:#f3f4f6;">
            <table style="width:100%%;max-width:600px;margin:24px auto;background:#fff;border-radius:8px;overflow:hidden;">
                <tr><td style="padding:24px 32px 8px;background:%s;color:#fff;">
                    <h1 style="margin:0;font-size:20px;">%s</h1>
                    <p style="margin:4px 0 0;opacity:0.9;">%s</p>
                </td></tr>
                <tr><td style="padding:16px 32px;">
                    <p>Dear <strong>%s</strong>,</p>
                    <p>Please find your invoice details below.</p>
                    <table style="border-collapse:collapse;width:100%%;margin:12px 0;">
                        <tr><td style="padding:6px 8px;background:#f9fafb;font-weight:700;">Invoice</td>
                            <td style="padding:6px 8px;background:#f9fafb;">%s</td></tr>
                        <tr><td style="padding:6px 8px;font-weight:700;">Status</td>
                            <td style="padding:6px 8px;">%s</td></tr>
                        <tr><td style="padding:6px 8px;background:#f9fafb;font-weight:700;">Total</td>
                            <td style="padding:6px 8px;background:#f9fafb;">%s %s</td></tr>
                    </table>
                    <h3 style="margin:16px 0 8px;font-size:14px;">Items</h3>
                    <table style="border-collapse:collapse;width:100%%;">
                        <thead><tr style="background:#f9fafb;">
                            <th style="padding:8px;text-align:left;font-size:12px;">Item</th>
                            <th style="padding:8px;text-align:center;font-size:12px;">Qty</th>
                            <th style="padding:8px;text-align:right;font-size:12px;">Amount</th>
                        </tr></thead>
                        <tbody>%s</tbody>
                    </table>
                    <p style="margin-top:20px;color:#6b7280;font-size:13px;">
                        The PDF copy is attached to this email for your records.
                    </p>
                </td></tr>
                <tr><td style="padding:16px 32px;background:#f9fafb;font-size:12px;color:#6b7280;text-align:center;">
                    %s &middot; Automated invoice notification
                </td></tr>
            </table>
            </body></html>
            """,
            isPaid ? "#059669" : "#2563eb",
            isPaid ? "Payment Received \u2705" : "Invoice",
            businessName,
            recipientName != null ? recipientName : "Valued Customer",
            saleNumber, statusLabel, symbol, total.toPlainString(),
            linesHtml.toString(),
            businessName);
    }
}
