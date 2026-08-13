package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "business_settings")
@Getter
@Setter
public class BusinessSettings extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "business_name", nullable = false, length = 150)
    private String businessName;

    @Column(name = "logo_url", columnDefinition = "TEXT")
    private String logoUrl;

    @Column(name = "khqr_image_url", columnDefinition = "TEXT")
    private String khqrImageUrl;

    @Column(length = 255)
    private String address;

    @Column(length = 50)
    private String phone;

    /** Website/link shown at the bottom of printed receipts (e.g. "www.example.com"). */
    @Column(length = 255)
    private String website;

    @Column(name = "tax_rate", nullable = false)
    private double taxRate;

    @Column(name = "currency", nullable = false, length = 10)
    private String currency;

    @Column(name = "receipt_footer", length = 255)
    private String receiptFooter;

    @Column(name = "default_language", length = 5)
    private String defaultLanguage;

    @Column(name = "require_shift_for_sales", nullable = false)
    private boolean requireShiftForSales = true;

    @Column(name = "show_demo_account", nullable = false)
    private boolean showDemoAccount = true;

    @Column(name = "pos_layout_config", columnDefinition = "LONGTEXT")
    private String posLayoutConfig;

    @Column(name = "open_ticket_config", columnDefinition = "LONGTEXT")
    private String openTicketConfig;

    // ── Loyverse-inspired settings ──────────────────────────────────────────

    /** Cash rounding mode: NONE, ROUND_UP, ROUND_DOWN, ROUND_NEAREST */
    @Column(name = "cash_rounding_mode", length = 20)
    private String cashRoundingMode = "NONE";

    /** Rounding interval in smallest currency unit (e.g. 50 for 50 riel) */
    @Column(name = "cash_rounding_interval")
    private int cashRoundingInterval = 0;

    /** Whether to show sale screen favorites */
    @Column(name = "enable_favorites", nullable = false)
    private boolean enableFavorites = false;

    /** Default sale screen layout: GRID, LIST, COMPACT */
    @Column(name = "sale_screen_layout", length = 20)
    private String saleScreenLayout = "GRID";

    /** Number of columns in the product grid */
    @Column(name = "product_grid_columns")
    private int productGridColumns = 4;

    /** Whether receipts auto-print after payment */
    @Column(name = "auto_print_receipt", nullable = false)
    private boolean autoPrintReceipt = false;

    /** Whether to show customer info on receipts */
    @Column(name = "receipt_show_customer", nullable = false)
    private boolean receiptShowCustomer = true;

    /** Whether to show item barcodes on receipts */
    @Column(name = "receipt_show_barcode", nullable = false)
    private boolean receiptShowBarcode = false;

    /** Receipt paper width in mm (58 or 80) */
    @Column(name = "receipt_paper_width")
    private int receiptPaperWidth = 58;

    /** Default discount preset JSON (array of {label, percent, amount}) */
    @Column(name = "discount_presets", columnDefinition = "TEXT")
    private String discountPresets;

    /** Whether discount is required on manager override */
    @Column(name = "require_discount_reason", nullable = false)
    private boolean requireDiscountReason = false;

    /** Whether PIN code is required to open POS */
    @Column(name = "require_pin_for_pos", nullable = false)
    private boolean requirePinForPos = false;

    /** Enable kitchen display integration */
    @Column(name = "enable_kitchen_display", nullable = false)
    private boolean enableKitchenDisplay = false;

    /** Kitchen display printer name/IP */
    @Column(name = "kitchen_printer_name", length = 100)
    private String kitchenPrinterName;

    /** Notify on low stock threshold */
    @Column(name = "low_stock_alert", nullable = false)
    private boolean lowStockAlert = true;

    /** Email address for low stock notifications */
    @Column(name = "low_stock_alert_email", length = 150)
    private String lowStockAlertEmail;
}
