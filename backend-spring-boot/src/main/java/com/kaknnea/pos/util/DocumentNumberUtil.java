package com.kaknnea.pos.util;

import com.kaknnea.pos.domain.CustomerAdjustment;
import com.kaknnea.pos.domain.GoodsReceipt;
import com.kaknnea.pos.domain.Payment;
import com.kaknnea.pos.domain.PurchaseOrder;
import com.kaknnea.pos.domain.Sale;

import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

public final class DocumentNumberUtil {
    private static final int DEFAULT_WIDTH = 5;

    private DocumentNumberUtil() {}

    /**
     * Returns the current year as a four-digit string (e.g., "2026").
     */
    private static String currentYear() {
        return String.valueOf(java.time.Year.now().getValue());
    }

    public static String saleNumber(Sale sale) {
        if (sale == null) {
            return null;
        }
        return normalizeGeneratedNumber(sale.getSaleNumber(), "INV", sale.getId(), Set.of("INV", "SALE"));
    }

    public static String saleReceiptNumber(Sale sale) {
        if (sale == null) {
            return null;
        }
        return normalizeGeneratedNumber(sale.getSaleNumber(), "SR", sale.getId(), Set.of("INV", "SALE", "SR"));
    }

    public static String heldTicketNumber(Sale sale) {
        if (sale == null) {
            return null;
        }
        return normalizeGeneratedNumber(sale.getSaleNumber(), "TKT", sale.getId(), Set.of("TKT", "TICKET"));
    }

    public static String estimateNumber(Sale sale) {
        if (sale == null) {
            return null;
        }
        String raw = trimToNull(sale.getSaleNumber());
        if (raw != null && raw.toUpperCase(Locale.ROOT).startsWith("EST-")) {
            return raw;
        }
        return format("EST", sale.getId());
    }

    public static String paymentReference(Payment payment) {
        if (payment == null) {
            return null;
        }
        String raw = trimToNull(payment.getReferenceNumber());
        if (raw == null) {
            return format("PAY", payment.getId());
        }
        String normalized = raw.toUpperCase(Locale.ROOT);
        if (normalized.startsWith("PAY-") || normalized.startsWith("COLLECT-")) {
            return format("PAY", payment.getId());
        }
        return raw;
    }

    public static String purchaseOrderNumber(PurchaseOrder order) {
        if (order == null) {
            return null;
        }
        return normalizeGeneratedNumber(order.getReferenceNumber(), "PO", order.getId(), Set.of("PO"));
    }

    public static String goodsReceiptNumber(GoodsReceipt receipt) {
        if (receipt == null) {
            return null;
        }
        return normalizeGeneratedNumber(receipt.getReferenceNumber(), "GRN", receipt.getId(), Set.of("GRN"));
    }

    public static String adjustmentNumber(CustomerAdjustment adjustment) {
        if (adjustment == null) {
            return null;
        }
        return normalizeGeneratedNumber(adjustment.getReferenceNumber(), "ADJ", adjustment.getId(), Set.of("ADJ"));
    }

    /**
     * Formats a document number with year prefix: PREFIX-YYYY-NNNNN
     * Example: INV-2026-00019
     */
    public static String format(String prefix, Long id) {
        if (id == null) {
            return null;
        }
        return prefix + "-" + currentYear() + "-" + String.format("%0" + DEFAULT_WIDTH + "d", id);
    }

    private static String normalizeGeneratedNumber(String rawValue, String targetPrefix, Long id, Set<String> legacyPrefixes) {
        String raw = trimToNull(rawValue);
        if (raw == null) {
            return format(targetPrefix, id);
        }
        String normalized = raw.toUpperCase(Locale.ROOT);
        if (normalized.matches("\\d+")) {
            return format(targetPrefix, id != null ? id : Long.valueOf(normalized));
        }

        Set<String> allowedPrefixes = new LinkedHashSet<>(legacyPrefixes);
        allowedPrefixes.add(targetPrefix);
        for (String prefix : allowedPrefixes) {
            if (normalized.matches(prefix + "-\\d+")
                    || normalized.matches(prefix + "-\\d{4}-\\d+")) {
                return format(targetPrefix, id);
            }
        }

        return raw;
    }

    private static String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
