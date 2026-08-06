package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "invoice_settings")
@Getter
@Setter
public class InvoiceSettings {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 20)
    private String prefix = "INV";

    @Column(name = "next_number", nullable = false)
    private Long nextNumber = 1L;

    @Column(length = 255)
    private String footer;

    @Column(name = "show_tax", nullable = false)
    private boolean showTax = true;

    @Column(name = "show_khqr", nullable = false)
    private boolean showKhqr = true;

    @Column(name = "printer_name", length = 100)
    private String printerName;

    @Column(name = "printer_type", length = 20)
    private String printerType;

    @Column(name = "printer_address", length = 100)
    private String printerAddress;

    @Column(name = "default_invoice_format", length = 20)
    private String defaultInvoiceFormat = "STANDARD";

    @Column(name = "default_receipt_format", length = 20)
    private String defaultReceiptFormat = "THERMAL";
}
