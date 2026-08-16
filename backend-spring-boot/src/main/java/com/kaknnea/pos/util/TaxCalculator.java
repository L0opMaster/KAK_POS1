package com.kaknnea.pos.util;

import com.kaknnea.pos.domain.SaleLine;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

/**
 * Tax is per-product now (see {@code Product.taxRate}) — every place that
 * finalizes a sale's totals needs the exact same per-line calculation, so it
 * lives here once instead of being copied into {@code SaleService} (create/
 * update/createEstimate) and {@code HeldTicketService}
 * (recalculateTotals/syncLinesFromRequest) separately, which is how the old
 * single-flat-rate version of this logic had already drifted into three
 * near-identical copies before this class existed.
 */
public final class TaxCalculator {
    private TaxCalculator() {
    }

    /**
     * Sums each line's own tax, at its own product's rate. An invoice-level
     * discount is prorated across lines by each line's share of the
     * pre-discount subtotal before taxing, so a discount still reduces the
     * taxable base the same way a single flat-rate calculation did, just
     * per line instead of once for the whole sale.
     */
    public static BigDecimal computeLineTaxes(List<SaleLine> lines, BigDecimal subtotal, BigDecimal discount) {
        if (subtotal.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO;
        }
        BigDecimal total = BigDecimal.ZERO;
        for (SaleLine line : lines) {
            BigDecimal share = line.getLineTotal().divide(subtotal, 10, RoundingMode.HALF_UP);
            BigDecimal lineDiscount = discount.multiply(share);
            BigDecimal taxableLine = line.getLineTotal().subtract(lineDiscount);
            total = total.add(taxableLine.multiply(BigDecimal.valueOf(line.getTaxRate())));
        }
        return total.setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * Blended effective rate for display only (e.g. a receipt's "Tax (X%)"
     * line) — {@code Sale.taxRate} can no longer mean "the one rate
     * applied," since lines can each have their own; this derives the
     * equivalent single rate from the actual computed tax.
     */
    public static double blendedTaxRate(BigDecimal taxable, BigDecimal taxAmount) {
        if (taxable.compareTo(BigDecimal.ZERO) <= 0) {
            return 0;
        }
        return taxAmount.divide(taxable, 10, RoundingMode.HALF_UP).doubleValue();
    }
}
