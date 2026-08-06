package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.SettingsDtos;
import com.kaknnea.pos.dto.UnitDtos;
import com.kaknnea.pos.service.SettingsService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/settings")
public class SettingsController {
    private final SettingsService settingsService;

    public SettingsController(SettingsService settingsService) {
        this.settingsService = settingsService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.SettingsResponse get() {
        return settingsService.get();
    }

    @PutMapping
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.SettingsResponse update(@Valid @RequestBody SettingsDtos.SettingsRequest request) {
        return settingsService.update(request);
    }

    @GetMapping("/business")
    @PreAuthorize("isAuthenticated()")
    public SettingsDtos.BusinessSettingsResponse getBusiness() {
        return settingsService.getBusiness();
    }

    @PutMapping("/business")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.BusinessSettingsResponse updateBusiness(@Valid @RequestBody SettingsDtos.BusinessSettingsRequest request) {
        return settingsService.updateBusiness(request);
    }

    @GetMapping("/invoice")
    @PreAuthorize("isAuthenticated()")
    public SettingsDtos.InvoiceSettingsResponse getInvoice() {
        return settingsService.getInvoice();
    }

    @PutMapping("/invoice")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.InvoiceSettingsResponse updateInvoice(@Valid @RequestBody SettingsDtos.InvoiceSettingsRequest request) {
        return settingsService.updateInvoice(request);
    }

    @GetMapping("/public")
    public SettingsDtos.PublicSettingsResponse getPublic() {
        return settingsService.getPublic();
    }

    @GetMapping("/general")
    @PreAuthorize("isAuthenticated()")
    public SettingsDtos.GeneralSettingsResponse getGeneral() {
        return settingsService.getGeneral();
    }

    @PutMapping("/general")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.GeneralSettingsResponse updateGeneral(@RequestBody SettingsDtos.GeneralSettingsRequest request) {
        return settingsService.updateGeneral(request);
    }

    @GetMapping("/company-profile")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.CompanyProfileSettingsResponse getCompanyProfile() {
        return settingsService.getCompanyProfile();
    }

    @PutMapping("/company-profile")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.CompanyProfileSettingsResponse updateCompanyProfile(
            @Valid @RequestBody SettingsDtos.CompanyProfileSettingsRequest request) {
        return settingsService.updateCompanyProfile(request);
    }

    @GetMapping("/tax")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.TaxSettingsResponse getTax() {
        return settingsService.getTax();
    }

    @PutMapping("/tax")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.TaxSettingsResponse updateTax(@RequestBody SettingsDtos.TaxSettingsRequest request) {
        return settingsService.updateTax(request);
    }

    @GetMapping("/printers")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PrinterSettingsResponse getPrinters() {
        return settingsService.getPrinters();
    }

    @PutMapping("/printers")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PrinterSettingsResponse updatePrinters(@RequestBody SettingsDtos.PrinterSettingsRequest request) {
        return settingsService.updatePrinters(request);
    }

    @GetMapping("/payment-methods")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public Page<SettingsDtos.PaymentMethodResponse> listPaymentMethods(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(required = false) Boolean active,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return settingsService.listPaymentMethods(q, active, page, size);
    }

    @GetMapping("/payment-methods/{id}")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PaymentMethodResponse getPaymentMethod(@PathVariable Long id) {
        return settingsService.getPaymentMethod(id);
    }

    @PostMapping("/payment-methods")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PaymentMethodResponse createPaymentMethod(
            @Valid @RequestBody SettingsDtos.PaymentMethodRequest request) {
        return settingsService.createPaymentMethod(request);
    }

    @PutMapping("/payment-methods/{id}")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PaymentMethodResponse updatePaymentMethod(@PathVariable Long id,
            @Valid @RequestBody SettingsDtos.PaymentMethodRequest request) {
        return settingsService.updatePaymentMethod(id, request);
    }

    @PatchMapping("/payment-methods/{id}/status")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PaymentMethodResponse updatePaymentMethodStatus(@PathVariable Long id,
            @RequestBody SettingsDtos.PaymentMethodStatusRequest request) {
        return settingsService.updatePaymentMethodStatus(id, request.isActive());
    }

    @GetMapping("/currencies")
    @PreAuthorize("isAuthenticated()")
    public Page<SettingsDtos.CurrencyResponse> listCurrencies(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(required = false) Boolean active,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return settingsService.listCurrencies(q, active, page, size);
    }

    @GetMapping("/currencies/{id}")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.CurrencyResponse getCurrency(@PathVariable Long id) {
        return settingsService.getCurrency(id);
    }

    @PostMapping("/currencies")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.CurrencyResponse createCurrency(@Valid @RequestBody SettingsDtos.CurrencyRequest request) {
        return settingsService.createCurrency(request);
    }

    @PutMapping("/currencies/{id}")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.CurrencyResponse updateCurrency(@PathVariable Long id,
            @Valid @RequestBody SettingsDtos.CurrencyRequest request) {
        return settingsService.updateCurrency(id, request);
    }

    @PatchMapping("/currencies/{id}/status")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.CurrencyResponse updateCurrencyStatus(@PathVariable Long id,
            @RequestBody SettingsDtos.CurrencyStatusRequest request) {
        return settingsService.updateCurrencyStatus(id, request.isActive());
    }

    @GetMapping("/units")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public List<UnitDtos.UnitResponse> listUnits() {
        return settingsService.listUnits();
    }

    @GetMapping("/pos-layout")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PosLayoutSettingsResponse getPosLayout() {
        return settingsService.getPosLayout();
    }

    @PutMapping("/pos-layout")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PosLayoutSettingsResponse updatePosLayout(
            @RequestBody SettingsDtos.PosLayoutSettingsRequest request) {
        return settingsService.updatePosLayout(request);
    }

    @GetMapping("/open-tickets")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.OpenTicketSettingsResponse getOpenTicketSettings() {
        return settingsService.getOpenTicketSettings();
    }

    @PutMapping("/open-tickets")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.OpenTicketSettingsResponse updateOpenTicketSettings(
            @RequestBody SettingsDtos.OpenTicketSettingsRequest request) {
        return settingsService.updateOpenTicketSettings(request);
    }

    @GetMapping("/pos")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PosSettingsResponse getPosSettings() {
        return settingsService.getPosSettings();
    }

    @PutMapping("/pos")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.PosSettingsResponse updatePosSettings(
            @RequestBody SettingsDtos.PosSettingsRequest request) {
        return settingsService.updatePosSettings(request);
    }

    @GetMapping("/discount-presets")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.DiscountPresetsResponse getDiscountPresets() {
        return settingsService.getDiscountPresets();
    }

    @PutMapping("/discount-presets")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public SettingsDtos.DiscountPresetsResponse updateDiscountPresets(
            @RequestBody SettingsDtos.DiscountPresetsRequest request) {
        return settingsService.updateDiscountPresets(request);
    }

    @GetMapping("/import-templates/{templateType}")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public ResponseEntity<byte[]> downloadImportTemplate(@PathVariable String templateType) {
        byte[] csv = settingsService.importTemplateCsv(templateType);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + templateType + "-template.csv\"")
                .body(csv);
    }
}
