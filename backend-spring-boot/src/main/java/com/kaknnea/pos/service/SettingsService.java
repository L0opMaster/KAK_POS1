package com.kaknnea.pos.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kaknnea.pos.domain.BusinessSettings;
import com.kaknnea.pos.domain.CurrencySetting;
import com.kaknnea.pos.domain.InvoiceSettings;
import com.kaknnea.pos.domain.PaymentMethod;
import com.kaknnea.pos.dto.SettingsDtos;
import com.kaknnea.pos.dto.UnitDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.BusinessSettingsRepository;
import com.kaknnea.pos.repository.CurrencySettingRepository;
import com.kaknnea.pos.repository.InvoiceSettingsRepository;
import com.kaknnea.pos.repository.PaymentMethodRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.SecurityUtil;
import java.nio.charset.StandardCharsets;
import java.math.BigDecimal;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SettingsService {
    private static final Logger log = LoggerFactory.getLogger(SettingsService.class);
    private final BusinessSettingsRepository repository;
    private final InvoiceSettingsRepository invoiceSettingsRepository;
    private final PaymentMethodRepository paymentMethodRepository;
    private final CurrencySettingRepository currencySettingRepository;
    private final UnitService unitService;
    private final AuditService auditService;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;

    public SettingsService(BusinessSettingsRepository repository, InvoiceSettingsRepository invoiceSettingsRepository,
            PaymentMethodRepository paymentMethodRepository, CurrencySettingRepository currencySettingRepository,
            UnitService unitService, AuditService auditService, UserRepository userRepository, ObjectMapper objectMapper) {
        this.repository = repository;
        this.invoiceSettingsRepository = invoiceSettingsRepository;
        this.paymentMethodRepository = paymentMethodRepository;
        this.currencySettingRepository = currencySettingRepository;
        this.unitService = unitService;
        this.auditService = auditService;
        this.userRepository = userRepository;
        this.objectMapper = objectMapper;
    }

    public SettingsDtos.SettingsResponse get() {
        BusinessSettings settings = findSettingsRecord().orElse(null);
        if (settings == null) {
            SettingsDtos.SettingsResponse resp = new SettingsDtos.SettingsResponse();
            resp.setBusinessName("KAKNNEA POS");
            resp.setCurrency("KHR");
            resp.setDefaultLanguage("km");
            resp.setTaxRate(0.0);
            return resp;
        }
        return toResponse(settings);
    }

    @Transactional
    public SettingsDtos.SettingsResponse update(SettingsDtos.SettingsRequest request) {
        BusinessSettings before = findSettingsRecord().orElse(null);
        BusinessSettings settings = before != null ? before : new BusinessSettings();
        settings.setBusinessName(request.getBusinessName());
        settings.setLogoUrl(request.getLogoUrl());
        settings.setAddress(request.getAddress());
        settings.setPhone(request.getPhone());
        settings.setTaxRate(request.getTaxRate());
        settings.setCurrency(request.getCurrency());
        settings.setReceiptFooter(request.getReceiptFooter());
        settings.setDefaultLanguage(normalizeLanguage(request.getDefaultLanguage()));
        if (request.getRequireShiftForSales() != null) {
            settings.setRequireShiftForSales(request.getRequireShiftForSales());
        }
        BusinessSettings saved = repository.save(settings);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SETTINGS_UPDATE", "BusinessSettings", String.valueOf(saved.getId()), before, saved);
        return toResponse(saved);
    }

    public SettingsDtos.BusinessSettingsResponse getBusiness() {
        return toBusinessResponse(getOrCreateBusinessSettings());
    }

    @Transactional
    public SettingsDtos.BusinessSettingsResponse updateBusiness(SettingsDtos.BusinessSettingsRequest request) {
        BusinessSettings before = findSettingsRecord().orElse(null);
        BusinessSettings settings = before != null ? before : new BusinessSettings();
        settings.setBusinessName(request.getBusinessName());
        settings.setLogoUrl(request.getLogoUrl());
        settings.setAddress(request.getAddress());
        settings.setPhone(request.getPhone());
        settings.setTaxRate(request.getTaxRate());
        settings.setCurrency(request.getCurrency());
        settings.setReceiptFooter(request.getReceiptFooter());
        settings.setDefaultLanguage(normalizeLanguage(request.getDefaultLanguage()));
        if (request.getRequireShiftForSales() != null) {
            settings.setRequireShiftForSales(request.getRequireShiftForSales());
        }
        BusinessSettings saved = repository.save(settings);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SETTINGS_BUSINESS_UPDATE", "BusinessSettings", String.valueOf(saved.getId()), before,
                saved);
        return toBusinessResponse(saved);
    }

    public SettingsDtos.InvoiceSettingsResponse getInvoice() {
        return toInvoiceResponse(getOrCreateInvoiceSettings());
    }

    @Transactional
    public SettingsDtos.InvoiceSettingsResponse updateInvoice(SettingsDtos.InvoiceSettingsRequest request) {
        InvoiceSettings before = invoiceSettingsRepository.findAll().stream().findFirst().orElse(null);
        InvoiceSettings settings = before != null ? before : new InvoiceSettings();
        if (request.getPrefix() != null)
            settings.setPrefix(request.getPrefix());
        if (request.getNextNumber() != null)
            settings.setNextNumber(request.getNextNumber());
        settings.setFooter(request.getFooter());
        if (request.getShowTax() != null) {
            settings.setShowTax(request.getShowTax());
        }
        if (request.getShowKhqr() != null) {
            settings.setShowKhqr(request.getShowKhqr());
        }
        settings.setPrinterName(request.getPrinterName());
        settings.setPrinterType(request.getPrinterType());
        settings.setPrinterAddress(request.getPrinterAddress());
        if (request.getDefaultInvoiceFormat() != null) {
            settings.setDefaultInvoiceFormat(request.getDefaultInvoiceFormat());
        }
        if (request.getDefaultReceiptFormat() != null) {
            settings.setDefaultReceiptFormat(request.getDefaultReceiptFormat());
        }
        InvoiceSettings saved = invoiceSettingsRepository.save(settings);
        var actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElse(null);
        auditService.log(actor, "SETTINGS_INVOICE_UPDATE", "InvoiceSettings", String.valueOf(saved.getId()), before,
                saved);
        return toInvoiceResponse(saved);
    }

    private SettingsDtos.SettingsResponse toResponse(BusinessSettings settings) {
        if (settings == null)
            return null;
        SettingsDtos.SettingsResponse resp = new SettingsDtos.SettingsResponse();
        resp.setId(settings.getId());
        resp.setBusinessName(settings.getBusinessName());
        resp.setLogoUrl(settings.getLogoUrl());
        resp.setAddress(settings.getAddress());
        resp.setPhone(settings.getPhone());
        resp.setTaxRate(settings.getTaxRate());
        resp.setCurrency(settings.getCurrency());
        resp.setReceiptFooter(settings.getReceiptFooter());
        resp.setDefaultLanguage(normalizeLanguage(settings.getDefaultLanguage()));
        resp.setRequireShiftForSales(settings.isRequireShiftForSales());
        return resp;
    }

    private SettingsDtos.BusinessSettingsResponse toBusinessResponse(BusinessSettings settings) {
        SettingsDtos.BusinessSettingsResponse resp = new SettingsDtos.BusinessSettingsResponse();
        resp.setId(settings.getId());
        resp.setBusinessName(settings.getBusinessName());
        resp.setLogoUrl(settings.getLogoUrl());
        resp.setAddress(settings.getAddress());
        resp.setPhone(settings.getPhone());
        resp.setTaxRate(settings.getTaxRate());
        resp.setCurrency(settings.getCurrency());
        resp.setReceiptFooter(settings.getReceiptFooter());
        resp.setDefaultLanguage(normalizeLanguage(settings.getDefaultLanguage()));
        resp.setRequireShiftForSales(settings.isRequireShiftForSales());
        return resp;
    }

    private SettingsDtos.InvoiceSettingsResponse toInvoiceResponse(InvoiceSettings settings) {
        SettingsDtos.InvoiceSettingsResponse resp = new SettingsDtos.InvoiceSettingsResponse();
        resp.setId(settings.getId());
        resp.setPrefix(settings.getPrefix());
        resp.setNextNumber(settings.getNextNumber());
        resp.setFooter(settings.getFooter());
        resp.setShowTax(settings.isShowTax());
        resp.setShowKhqr(settings.isShowKhqr());
        resp.setPrinterName(settings.getPrinterName());
        resp.setPrinterType(settings.getPrinterType());
        resp.setPrinterAddress(settings.getPrinterAddress());
        resp.setDefaultInvoiceFormat(settings.getDefaultInvoiceFormat());
        resp.setDefaultReceiptFormat(settings.getDefaultReceiptFormat());
        return resp;
    }

    public SettingsDtos.PublicSettingsResponse getPublic() {
        BusinessSettings businessSettings = getOrCreateBusinessSettings();
        SettingsDtos.PublicSettingsResponse response = new SettingsDtos.PublicSettingsResponse();
        response.setShowDemoAccount(businessSettings.isShowDemoAccount());
        return response;
    }

    public SettingsDtos.GeneralSettingsResponse getGeneral() {
        BusinessSettings businessSettings = getOrCreateBusinessSettings();
        InvoiceSettings invoiceSettings = getOrCreateInvoiceSettings();
        SettingsDtos.GeneralSettingsResponse response = new SettingsDtos.GeneralSettingsResponse();
        response.setDefaultLanguage(normalizeLanguage(businessSettings.getDefaultLanguage()));
        response.setCurrency(businessSettings.getCurrency());
        response.setReceiptFooter(businessSettings.getReceiptFooter());
        response.setDefaultInvoiceFormat(invoiceSettings.getDefaultInvoiceFormat());
        response.setDefaultReceiptFormat(invoiceSettings.getDefaultReceiptFormat());
        response.setShowKhqr(invoiceSettings.isShowKhqr());
        response.setRequireShiftForSales(businessSettings.isRequireShiftForSales());
        response.setShowDemoAccount(businessSettings.isShowDemoAccount());
        return response;
    }

    @Transactional
    public SettingsDtos.GeneralSettingsResponse updateGeneral(SettingsDtos.GeneralSettingsRequest request) {
        BusinessSettings businessSettings = getOrCreateBusinessSettings();
        InvoiceSettings invoiceSettings = getOrCreateInvoiceSettings();
        if (request.getDefaultLanguage() != null) {
            businessSettings.setDefaultLanguage(normalizeLanguage(request.getDefaultLanguage()));
        }
        if (request.getCurrency() != null) {
            businessSettings.setCurrency(request.getCurrency());
        }
        if (request.getReceiptFooter() != null) {
            businessSettings.setReceiptFooter(request.getReceiptFooter());
        }
        if (request.getDefaultInvoiceFormat() != null) {
            invoiceSettings.setDefaultInvoiceFormat(request.getDefaultInvoiceFormat());
        }
        if (request.getDefaultReceiptFormat() != null) {
            invoiceSettings.setDefaultReceiptFormat(request.getDefaultReceiptFormat());
        }
        if (request.getShowKhqr() != null) {
            invoiceSettings.setShowKhqr(request.getShowKhqr());
        }
        if (request.getRequireShiftForSales() != null) {
            businessSettings.setRequireShiftForSales(request.getRequireShiftForSales());
        }
        if (request.getShowDemoAccount() != null) {
            businessSettings.setShowDemoAccount(request.getShowDemoAccount());
        }
        repository.save(businessSettings);
        invoiceSettingsRepository.save(invoiceSettings);
        return getGeneral();
    }

    public SettingsDtos.CompanyProfileSettingsResponse getCompanyProfile() {
        BusinessSettings settings = getOrCreateBusinessSettings();
        SettingsDtos.CompanyProfileSettingsResponse response = new SettingsDtos.CompanyProfileSettingsResponse();
        response.setId(settings.getId());
        response.setBusinessName(settings.getBusinessName());
        response.setLogoUrl(settings.getLogoUrl());
        response.setAddress(settings.getAddress());
        response.setPhone(settings.getPhone());
        response.setWebsite(settings.getWebsite());
        response.setReceiptFooter(settings.getReceiptFooter());
        response.setKhqrImageUrl(settings.getKhqrImageUrl());
        return response;
    }

    @Transactional
    public SettingsDtos.CompanyProfileSettingsResponse updateCompanyProfile(SettingsDtos.CompanyProfileSettingsRequest request) {
        BusinessSettings settings = getOrCreateBusinessSettings();
        settings.setBusinessName(request.getBusinessName());
        settings.setLogoUrl(request.getLogoUrl());
        settings.setAddress(request.getAddress());
        settings.setPhone(request.getPhone());
        settings.setWebsite(request.getWebsite());
        settings.setReceiptFooter(request.getReceiptFooter());
        settings.setKhqrImageUrl(request.getKhqrImageUrl());
        repository.save(settings);
        return getCompanyProfile();
    }

    public SettingsDtos.TaxSettingsResponse getTax() {
        BusinessSettings businessSettings = getOrCreateBusinessSettings();
        InvoiceSettings invoiceSettings = getOrCreateInvoiceSettings();
        SettingsDtos.TaxSettingsResponse response = new SettingsDtos.TaxSettingsResponse();
        response.setTaxRate(businessSettings.getTaxRate());
        response.setShowTax(invoiceSettings.isShowTax());
        return response;
    }

    @Transactional
    public SettingsDtos.TaxSettingsResponse updateTax(SettingsDtos.TaxSettingsRequest request) {
        BusinessSettings businessSettings = getOrCreateBusinessSettings();
        InvoiceSettings invoiceSettings = getOrCreateInvoiceSettings();
        businessSettings.setTaxRate(request.getTaxRate());
        if (request.getShowTax() != null) {
            invoiceSettings.setShowTax(request.getShowTax());
        }
        repository.save(businessSettings);
        invoiceSettingsRepository.save(invoiceSettings);
        return getTax();
    }

    public SettingsDtos.PrinterSettingsResponse getPrinters() {
        InvoiceSettings settings = getOrCreateInvoiceSettings();
        SettingsDtos.PrinterSettingsResponse response = new SettingsDtos.PrinterSettingsResponse();
        response.setPrinterName(settings.getPrinterName());
        response.setPrinterType(settings.getPrinterType());
        response.setPrinterAddress(settings.getPrinterAddress());
        response.setDefaultInvoiceFormat(settings.getDefaultInvoiceFormat());
        response.setDefaultReceiptFormat(settings.getDefaultReceiptFormat());
        response.setInvoicePrefix(settings.getPrefix());
        response.setNextInvoiceNumber(settings.getNextNumber());
        response.setInvoiceFooter(settings.getFooter());
        return response;
    }

    @Transactional
    public SettingsDtos.PrinterSettingsResponse updatePrinters(SettingsDtos.PrinterSettingsRequest request) {
        InvoiceSettings settings = getOrCreateInvoiceSettings();
        settings.setPrinterName(request.getPrinterName());
        settings.setPrinterType(request.getPrinterType());
        settings.setPrinterAddress(request.getPrinterAddress());
        if (request.getDefaultInvoiceFormat() != null) {
            settings.setDefaultInvoiceFormat(request.getDefaultInvoiceFormat());
        }
        if (request.getDefaultReceiptFormat() != null) {
            settings.setDefaultReceiptFormat(request.getDefaultReceiptFormat());
        }
        if (request.getInvoicePrefix() != null) {
            settings.setPrefix(request.getInvoicePrefix());
        }
        if (request.getNextInvoiceNumber() != null) {
            settings.setNextNumber(request.getNextInvoiceNumber());
        }
        if (request.getInvoiceFooter() != null) {
            settings.setFooter(request.getInvoiceFooter());
        }
        invoiceSettingsRepository.save(settings);
        return getPrinters();
    }

    public Page<SettingsDtos.PaymentMethodResponse> listPaymentMethods(String q, Boolean active, int page, int size) {
        return paymentMethodRepository.search(q == null ? "" : q.trim(), active, PageRequest.of(page, size))
                .map(this::toPaymentMethodResponse);
    }

    public SettingsDtos.PaymentMethodResponse getPaymentMethod(Long id) {
        return toPaymentMethodResponse(findPaymentMethod(id));
    }

    @Transactional
    public SettingsDtos.PaymentMethodResponse createPaymentMethod(SettingsDtos.PaymentMethodRequest request) {
        PaymentMethod paymentMethod = new PaymentMethod();
        applyPaymentMethod(paymentMethod, request);
        return toPaymentMethodResponse(paymentMethodRepository.save(paymentMethod));
    }

    @Transactional
    public SettingsDtos.PaymentMethodResponse updatePaymentMethod(Long id, SettingsDtos.PaymentMethodRequest request) {
        PaymentMethod paymentMethod = findPaymentMethod(id);
        applyPaymentMethod(paymentMethod, request);
        return toPaymentMethodResponse(paymentMethodRepository.save(paymentMethod));
    }

    @Transactional
    public SettingsDtos.PaymentMethodResponse updatePaymentMethodStatus(Long id, boolean active) {
        PaymentMethod paymentMethod = findPaymentMethod(id);
        paymentMethod.setActive(active);
        return toPaymentMethodResponse(paymentMethodRepository.save(paymentMethod));
    }

    public Page<SettingsDtos.CurrencyResponse> listCurrencies(String q, Boolean active, int page, int size) {
        return currencySettingRepository.search(q == null ? "" : q.trim(), active, PageRequest.of(page, size))
                .map(this::toCurrencyResponse);
    }

    public SettingsDtos.CurrencyResponse getCurrency(Long id) {
        return toCurrencyResponse(findCurrency(id));
    }

    @Transactional
    public SettingsDtos.CurrencyResponse createCurrency(SettingsDtos.CurrencyRequest request) {
        CurrencySetting currency = new CurrencySetting();
        applyCurrency(currency, request);
        return toCurrencyResponse(currencySettingRepository.save(currency));
    }

    @Transactional
    public SettingsDtos.CurrencyResponse updateCurrency(Long id, SettingsDtos.CurrencyRequest request) {
        CurrencySetting currency = findCurrency(id);
        applyCurrency(currency, request);
        return toCurrencyResponse(currencySettingRepository.save(currency));
    }

    @Transactional
    public SettingsDtos.CurrencyResponse updateCurrencyStatus(Long id, boolean active) {
        CurrencySetting currency = findCurrency(id);
        if (currency.isDefaultCurrency() && !active) {
            throw new ApiException("Default currency cannot be deactivated");
        }
        currency.setActive(active);
        return toCurrencyResponse(currencySettingRepository.save(currency));
    }

    public List<UnitDtos.UnitResponse> listUnits() {
        return unitService.listAll();
    }

    public SettingsDtos.PosLayoutSettingsResponse getPosLayout() {
        BusinessSettings settings = getOrCreateBusinessSettings();
        SettingsDtos.PosLayoutSettingsResponse stored = readJson(
                settings.getPosLayoutConfig(),
                SettingsDtos.PosLayoutSettingsResponse.class,
                defaultPosLayoutSettings());
        return normalizePosLayout(stored);
    }

    @Transactional
    public SettingsDtos.PosLayoutSettingsResponse updatePosLayout(SettingsDtos.PosLayoutSettingsRequest request) {
        BusinessSettings settings = getOrCreateBusinessSettings();
        SettingsDtos.PosLayoutSettingsResponse normalized = normalizePosLayout(copyPosLayout(request));
        settings.setPosLayoutConfig(writeJson(normalized));
        repository.save(settings);
        return normalized;
    }

    public SettingsDtos.OpenTicketSettingsResponse getOpenTicketSettings() {
        BusinessSettings settings = getOrCreateBusinessSettings();
        SettingsDtos.OpenTicketSettingsResponse stored = readJson(
                settings.getOpenTicketConfig(),
                SettingsDtos.OpenTicketSettingsResponse.class,
                defaultOpenTicketSettings());
        return normalizeOpenTicketSettings(stored);
    }

    @Transactional
    public SettingsDtos.OpenTicketSettingsResponse updateOpenTicketSettings(SettingsDtos.OpenTicketSettingsRequest request) {
        BusinessSettings settings = getOrCreateBusinessSettings();
        SettingsDtos.OpenTicketSettingsResponse normalized = normalizeOpenTicketSettings(copyOpenTicketSettings(request));
        settings.setOpenTicketConfig(writeJson(normalized));
        repository.save(settings);
        return normalized;
    }

    private PaymentMethod applyPaymentMethod(PaymentMethod paymentMethod, SettingsDtos.PaymentMethodRequest request) {
        String code = request.getCode().trim().toUpperCase(Locale.US);
        if (paymentMethod.getId() == null) {
            paymentMethodRepository.findByCode(code).ifPresent(existing -> {
                throw new ApiException("Payment method code already exists");
            });
        } else if (paymentMethodRepository.existsByCodeAndIdNot(code, paymentMethod.getId())) {
            throw new ApiException("Payment method code already exists");
        }
        paymentMethod.setCode(code);
        paymentMethod.setName(request.getName().trim());
        paymentMethod.setDisplayOrder(request.getDisplayOrder());
        paymentMethod.setCash(request.isCash());
        paymentMethod.setActive(request.isActive());
        return paymentMethod;
    }

    private SettingsDtos.PaymentMethodResponse toPaymentMethodResponse(PaymentMethod paymentMethod) {
        SettingsDtos.PaymentMethodResponse response = new SettingsDtos.PaymentMethodResponse();
        response.setId(paymentMethod.getId());
        response.setCode(paymentMethod.getCode());
        response.setName(paymentMethod.getName());
        response.setDisplayOrder(paymentMethod.getDisplayOrder());
        response.setCash(paymentMethod.isCash());
        response.setActive(paymentMethod.isActive());
        return response;
    }

    private PaymentMethod findPaymentMethod(Long id) {
        return paymentMethodRepository.findById(id)
                .orElseThrow(() -> new ApiException("Payment method not found"));
    }

    private CurrencySetting applyCurrency(CurrencySetting currency, SettingsDtos.CurrencyRequest request) {
        String code = request.getCode().trim().toUpperCase(Locale.US);
        if (currency.getId() == null) {
            currencySettingRepository.findByCode(code).ifPresent(existing -> {
                throw new ApiException("Currency code already exists");
            });
        } else if (currencySettingRepository.existsByCodeAndIdNot(code, currency.getId())) {
            throw new ApiException("Currency code already exists");
        }
        if (request.isDefaultCurrency()) {
            currencySettingRepository.findAll().forEach(existing -> {
                if (!existing.getId().equals(currency.getId())) {
                    existing.setDefaultCurrency(false);
                    currencySettingRepository.save(existing);
                }
            });
        }
        currency.setCode(code);
        currency.setName(request.getName().trim());
        currency.setSymbol(request.getSymbol().trim());
        currency.setExchangeRate(request.getExchangeRate() == null ? BigDecimal.ONE : request.getExchangeRate());
        currency.setDisplayOrder(request.getDisplayOrder());
        currency.setDefaultCurrency(request.isDefaultCurrency());
        currency.setActive(request.isActive());
        return currency;
    }

    private SettingsDtos.CurrencyResponse toCurrencyResponse(CurrencySetting currency) {
        SettingsDtos.CurrencyResponse response = new SettingsDtos.CurrencyResponse();
        response.setId(currency.getId());
        response.setCode(currency.getCode());
        response.setName(currency.getName());
        response.setSymbol(currency.getSymbol());
        response.setExchangeRate(currency.getExchangeRate());
        response.setDisplayOrder(currency.getDisplayOrder());
        response.setDefaultCurrency(currency.isDefaultCurrency());
        response.setActive(currency.isActive());
        return response;
    }

    private CurrencySetting findCurrency(Long id) {
        return currencySettingRepository.findById(id)
                .orElseThrow(() -> new ApiException("Currency not found"));
    }

    private SettingsDtos.PosLayoutSettingsResponse defaultPosLayoutSettings() {
        SettingsDtos.PosLayoutSettingsResponse response = new SettingsDtos.PosLayoutSettingsResponse();
        response.setPreset("LOYVERSE_RESTAURANT");
        response.setDefaultMode("DINE_IN");
        response.setShowBarcode(true);
        response.setShowCustomerPanel(true);
        response.setShowHeldSales(true);
        response.setShowTables(true);
        response.setShowProductionInAdmin(true);
        response.setShowMoreOptionsButton(true);
        response.setMoreOptionsLabel("More Options");
        response.setMoreOptionsIcon("more_vert");
        response.setShowKeyboardShortcuts(true);
        response.setShowPayButton(true);
        response.setPayButtonLabel("Pay Now");
        response.setPayButtonIcon("credit_card");
        response.setOrderModes(List.of(
                orderMode("DINE_IN", "Dining In", "restaurant", true, 10),
                orderMode("TAKEAWAY", "Takeaway", "shopping_bag", true, 20),
                orderMode("DELIVERY", "Delivery", "local_shipping", true, 30)));
        response.setShowOtherCharges(true);
        response.setOtherChargesTitle("Other Charges");
        response.setOtherChargesIcon("add_circle");
        response.setAllowCustomOtherCharges(true);
        response.setOtherChargePresets(List.of(
                otherChargePreset("packaging", "Pack", "Packaging", "inventory_2", true, 10, "FIXED", "1000", "0", true, true),
                otherChargePreset("service_10", "Service 10%", "Service Charge", "room_service", true, 20, "PERCENT", "0", "10", true, true),
                otherChargePreset("rush", "Rush", "Rush Fee", "bolt", true, 30, "FIXED", "2000", "0", true, true)));
        response.setMenuSections(List.of(
                section("sale", "Sale", "point_of_sale", true, 10),
                section("tickets", "Open Tickets", "receipt_long", true, 20),
                section("tables", "Tables", "event_seat", true, 30),
                section("customers", "Customers", "people", true, 40),
                section("payment", "Payment", "payments", true, 50),
                section("more", "More", "more_horiz", true, 60)));
        response.setQuickActions(List.of(
                quickAction("hold", "Save Ticket", "schedule", true, 10, true, true),
                quickAction("tickets", "Open Tickets", "receipt_long", true, 20, true, true),
                quickAction("discount", "Discount", "sell", true, 30, true, true),
                quickAction("customer", "Customer", "person", true, 40, true, true),
                quickAction("note", "Note", "sticky_note_2", true, 50, true, true),
                quickAction("clear", "Clear", "delete_sweep", true, 60, true, true),
                quickAction("charge", "Charge", "payments", true, 70, true, true),
                quickAction("bill", "Print Bill", "receipt_long", true, 80, true, true),
                quickAction("refund", "Refund Sale", "undo", true, 90, true, true),
                quickAction("credit", "Credit Sale", "credit_card", true, 100, true, true),
                quickAction("shortcuts", "Keyboard Shortcuts", "keyboard", true, 110, true, true)));
        response.setCategoryPresentation(List.of());
        return response;
    }

    private SettingsDtos.OpenTicketSettingsResponse defaultOpenTicketSettings() {
        SettingsDtos.OpenTicketSettingsResponse response = new SettingsDtos.OpenTicketSettingsResponse();
        response.setEnableOpenTickets(true);
        response.setEnableTables(true);
        response.setEnableSplitMerge(true);
        response.setEnableTransfer(true);
        response.setPredefinedTicketPrefix("T");
        return response;
    }

    private SettingsDtos.PosLayoutSettingsResponse normalizePosLayout(SettingsDtos.PosLayoutSettingsResponse response) {
        SettingsDtos.PosLayoutSettingsResponse defaults = defaultPosLayoutSettings();
        if (response.getPreset() == null) response.setPreset(defaults.getPreset());
        if (response.getDefaultMode() == null) response.setDefaultMode(defaults.getDefaultMode());
        if (response.getShowBarcode() == null) response.setShowBarcode(defaults.getShowBarcode());
        if (response.getShowCustomerPanel() == null) response.setShowCustomerPanel(defaults.getShowCustomerPanel());
        if (response.getShowHeldSales() == null) response.setShowHeldSales(defaults.getShowHeldSales());
        if (response.getShowTables() == null) response.setShowTables(defaults.getShowTables());
        if (response.getShowProductionInAdmin() == null) response.setShowProductionInAdmin(defaults.getShowProductionInAdmin());
        if (response.getShowMoreOptionsButton() == null) response.setShowMoreOptionsButton(defaults.getShowMoreOptionsButton());
        if (response.getMoreOptionsLabel() == null || response.getMoreOptionsLabel().isBlank()) response.setMoreOptionsLabel(defaults.getMoreOptionsLabel());
        if (response.getMoreOptionsIcon() == null || response.getMoreOptionsIcon().isBlank()) response.setMoreOptionsIcon(defaults.getMoreOptionsIcon());
        if (response.getShowKeyboardShortcuts() == null) response.setShowKeyboardShortcuts(defaults.getShowKeyboardShortcuts());
        if (response.getShowPayButton() == null) response.setShowPayButton(defaults.getShowPayButton());
        if (response.getPayButtonLabel() == null || response.getPayButtonLabel().isBlank()) response.setPayButtonLabel(defaults.getPayButtonLabel());
        if (response.getPayButtonIcon() == null || response.getPayButtonIcon().isBlank()) response.setPayButtonIcon(defaults.getPayButtonIcon());
        if (response.getOrderModes() == null || response.getOrderModes().isEmpty()) response.setOrderModes(defaults.getOrderModes());
        if (response.getShowOtherCharges() == null) response.setShowOtherCharges(defaults.getShowOtherCharges());
        if (response.getOtherChargesTitle() == null || response.getOtherChargesTitle().isBlank()) response.setOtherChargesTitle(defaults.getOtherChargesTitle());
        if (response.getOtherChargesIcon() == null || response.getOtherChargesIcon().isBlank()) response.setOtherChargesIcon(defaults.getOtherChargesIcon());
        if (response.getAllowCustomOtherCharges() == null) response.setAllowCustomOtherCharges(defaults.getAllowCustomOtherCharges());
        if (response.getOtherChargePresets() == null || response.getOtherChargePresets().isEmpty()) response.setOtherChargePresets(defaults.getOtherChargePresets());
        if (response.getQuickActions() == null || response.getQuickActions().isEmpty()) response.setQuickActions(defaults.getQuickActions());
        if (response.getMenuSections() == null || response.getMenuSections().isEmpty()) response.setMenuSections(defaults.getMenuSections());
        if (response.getCategoryPresentation() == null) response.setCategoryPresentation(List.of());
        return response;
    }

    private SettingsDtos.OpenTicketSettingsResponse normalizeOpenTicketSettings(SettingsDtos.OpenTicketSettingsResponse response) {
        SettingsDtos.OpenTicketSettingsResponse defaults = defaultOpenTicketSettings();
        if (response.getEnableOpenTickets() == null) response.setEnableOpenTickets(defaults.getEnableOpenTickets());
        if (response.getEnableTables() == null) response.setEnableTables(defaults.getEnableTables());
        if (response.getEnableSplitMerge() == null) response.setEnableSplitMerge(defaults.getEnableSplitMerge());
        if (response.getEnableTransfer() == null) response.setEnableTransfer(defaults.getEnableTransfer());
        if (response.getPredefinedTicketPrefix() == null || response.getPredefinedTicketPrefix().isBlank()) {
            response.setPredefinedTicketPrefix(defaults.getPredefinedTicketPrefix());
        }
        return response;
    }

    private SettingsDtos.PosLayoutSettingsResponse copyPosLayout(SettingsDtos.PosLayoutSettingsRequest request) {
        SettingsDtos.PosLayoutSettingsResponse response = new SettingsDtos.PosLayoutSettingsResponse();
        response.setPreset(request.getPreset());
        response.setDefaultMode(request.getDefaultMode());
        response.setShowBarcode(request.getShowBarcode());
        response.setShowCustomerPanel(request.getShowCustomerPanel());
        response.setShowHeldSales(request.getShowHeldSales());
        response.setShowTables(request.getShowTables());
        response.setShowProductionInAdmin(request.getShowProductionInAdmin());
        response.setShowMoreOptionsButton(request.getShowMoreOptionsButton());
        response.setMoreOptionsLabel(request.getMoreOptionsLabel());
        response.setMoreOptionsIcon(request.getMoreOptionsIcon());
        response.setShowKeyboardShortcuts(request.getShowKeyboardShortcuts());
        response.setShowPayButton(request.getShowPayButton());
        response.setPayButtonLabel(request.getPayButtonLabel());
        response.setPayButtonIcon(request.getPayButtonIcon());
        response.setOrderModes(request.getOrderModes());
        response.setShowOtherCharges(request.getShowOtherCharges());
        response.setOtherChargesTitle(request.getOtherChargesTitle());
        response.setOtherChargesIcon(request.getOtherChargesIcon());
        response.setAllowCustomOtherCharges(request.getAllowCustomOtherCharges());
        response.setOtherChargePresets(request.getOtherChargePresets());
        response.setQuickActions(request.getQuickActions());
        response.setMenuSections(request.getMenuSections());
        response.setCategoryPresentation(request.getCategoryPresentation());
        return response;
    }

    private SettingsDtos.OpenTicketSettingsResponse copyOpenTicketSettings(SettingsDtos.OpenTicketSettingsRequest request) {
        SettingsDtos.OpenTicketSettingsResponse response = new SettingsDtos.OpenTicketSettingsResponse();
        response.setEnableOpenTickets(request.getEnableOpenTickets());
        response.setEnableTables(request.getEnableTables());
        response.setEnableSplitMerge(request.getEnableSplitMerge());
        response.setEnableTransfer(request.getEnableTransfer());
        response.setPredefinedTicketPrefix(request.getPredefinedTicketPrefix());
        return response;
    }

    private SettingsDtos.PosMenuSectionConfig section(String id, String label, String icon, boolean enabled, int order) {
        SettingsDtos.PosMenuSectionConfig config = new SettingsDtos.PosMenuSectionConfig();
        config.setId(id);
        config.setLabel(label);
        config.setIcon(icon);
        config.setEnabled(enabled);
        config.setOrder(order);
        return config;
    }

    private SettingsDtos.PosOrderModeConfig orderMode(String id, String label, String icon, boolean enabled, int order) {
        SettingsDtos.PosOrderModeConfig config = new SettingsDtos.PosOrderModeConfig();
        config.setId(id);
        config.setLabel(label);
        config.setIcon(icon);
        config.setEnabled(enabled);
        config.setOrder(order);
        return config;
    }

    private SettingsDtos.PosOtherChargePresetConfig otherChargePreset(String id, String label, String chargeLabel,
            String icon, boolean enabled, int order, String amountType, String amount, String percent,
            boolean visibleInRestaurant, boolean visibleInRetail) {
        SettingsDtos.PosOtherChargePresetConfig config = new SettingsDtos.PosOtherChargePresetConfig();
        config.setId(id);
        config.setLabel(label);
        config.setChargeLabel(chargeLabel);
        config.setIcon(icon);
        config.setEnabled(enabled);
        config.setOrder(order);
        config.setAmountType(amountType);
        config.setAmount(new java.math.BigDecimal(amount));
        config.setPercent(new java.math.BigDecimal(percent));
        config.setVisibleInRestaurant(visibleInRestaurant);
        config.setVisibleInRetail(visibleInRetail);
        return config;
    }

    private SettingsDtos.PosQuickActionConfig quickAction(String id, String label, String icon, boolean enabled,
            int order, boolean visibleInRestaurant, boolean visibleInRetail) {
        SettingsDtos.PosQuickActionConfig config = new SettingsDtos.PosQuickActionConfig();
        config.setId(id);
        config.setLabel(label);
        config.setIcon(icon);
        config.setEnabled(enabled);
        config.setOrder(order);
        config.setVisibleInRestaurant(visibleInRestaurant);
        config.setVisibleInRetail(visibleInRetail);
        return config;
    }

    private <T> T readJson(String json, Class<T> type, T fallback) {
        if (json == null || json.isBlank()) {
            return fallback;
        }
        try {
            return objectMapper.readValue(json, type);
        } catch (Exception ex) {
            log.warn("Failed to deserialize settings JSON for type {}. Falling back to defaults.", type.getSimpleName(), ex);
            return fallback;
        }
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException ex) {
            throw new ApiException("Failed to persist settings");
        }
    }

    public byte[] importTemplateCsv(String templateType) {
        String normalized = templateType == null ? "" : templateType.trim().toLowerCase(Locale.ROOT);
        Map<String, String> templates = Map.of(
                "products", """
                        sku,barcode,nameEn,nameKm,category,cost,price,productType,trackInventory,purchasable,sellable,lowStockThreshold
                        DEMO-001,880900001,Sample Product,ផលិតផលគំរូ,Beverages,2.50,5.00,SALE_ITEM,true,true,true,10
                        DEMO-002,880900002,Sample Ingredient,គ្រឿងផ្សំគំរូ,Raw Materials,8.00,0.00,INGREDIENT,true,true,false,25
                        """,
                "opening-stock", """
                        sku,storeCode,quantity,unitCost,lowStockThreshold,notes
                        DEMO-001,MAIN,120,2.50,10,Opening balance after go-live count
                        DEMO-002,MAIN,40,8.00,25,Prep stock opening balance
                        """,
                "suppliers", """
                        code,name,phone,email,address,paymentTerms,taxNumber,notes
                        SUP-001,Sample Supplier,+85512345678,supplier@example.com,Phnom Penh,Net 30,VAT-001,Primary supplier
                        SUP-002,Cold Chain Partner,+85598765432,coldchain@example.com,Takhmao,COD,,Frozen delivery vendor
                        """,
                "purchases", """
                        supplierCode,documentDate,reference,status,productSku,quantity,unitCost,taxPercent,notes
                        SUP-001,2026-03-08,PO-1001,DRAFT,DEMO-001,24,2.50,10,Initial stock purchase
                        SUP-002,2026-03-08,PO-1002,DRAFT,DEMO-002,10,8.00,0,Ingredient replenishment
                        """
        );
        String csv = templates.get(normalized);
        if (csv == null) {
            throw new ApiException("Unsupported template type");
        }
        return csv.getBytes(StandardCharsets.UTF_8);
    }

    private BusinessSettings getOrCreateBusinessSettings() {
        BusinessSettings settings = findSettingsRecord().orElse(null);
        if (settings == null) {
            settings = new BusinessSettings();
            settings.setBusinessName("KAKNNEA POS");
            settings.setCurrency("KHR");
            settings.setDefaultLanguage("km");
            settings.setTaxRate(0.0);
            settings.setReceiptFooter("Thank you for your purchase!");
            settings.setRequireShiftForSales(true);
            settings.setSaleScreenLayout("GRID");
            settings.setProductGridColumns(4);
            settings.setCashRoundingMode("NONE");
            settings.setEnableFavorites(false);
            settings.setAutoPrintReceipt(false);
            settings.setReceiptShowCustomer(true);
            settings.setReceiptPaperWidth(58);
            settings.setRequireDiscountReason(false);
            settings.setRequirePinForPos(false);
            settings.setEnableKitchenDisplay(false);
            settings.setLowStockAlert(true);
            settings = repository.save(settings);
        }
        return settings;
    }

    // ── Loyverse-inspired POS settings endpoints ─────────────────────────────

    public SettingsDtos.PosSettingsResponse getPosSettings() {
        BusinessSettings s = getOrCreateBusinessSettings();
        SettingsDtos.PosSettingsResponse r = new SettingsDtos.PosSettingsResponse();
        r.setSaleScreenLayout(s.getSaleScreenLayout());
        r.setProductGridColumns(s.getProductGridColumns());
        r.setCashRoundingMode(s.getCashRoundingMode());
        r.setCashRoundingInterval(s.getCashRoundingInterval());
        r.setEnableFavorites(s.isEnableFavorites());
        r.setAutoPrintReceipt(s.isAutoPrintReceipt());
        r.setReceiptShowCustomer(s.isReceiptShowCustomer());
        r.setReceiptShowBarcode(s.isReceiptShowBarcode());
        r.setReceiptPaperWidth(s.getReceiptPaperWidth());
        r.setRequireDiscountReason(s.isRequireDiscountReason());
        r.setRequirePinForPos(s.isRequirePinForPos());
        r.setEnableKitchenDisplay(s.isEnableKitchenDisplay());
        r.setKitchenPrinterName(s.getKitchenPrinterName());
        r.setLowStockAlert(s.isLowStockAlert());
        r.setLowStockAlertEmail(s.getLowStockAlertEmail());
        return r;
    }

    @Transactional
    public SettingsDtos.PosSettingsResponse updatePosSettings(SettingsDtos.PosSettingsRequest request) {
        BusinessSettings s = getOrCreateBusinessSettings();
        if (request.getSaleScreenLayout() != null) s.setSaleScreenLayout(request.getSaleScreenLayout());
        if (request.getProductGridColumns() != null) s.setProductGridColumns(request.getProductGridColumns());
        if (request.getCashRoundingMode() != null) s.setCashRoundingMode(request.getCashRoundingMode());
        if (request.getCashRoundingInterval() != null) s.setCashRoundingInterval(request.getCashRoundingInterval());
        if (request.getEnableFavorites() != null) s.setEnableFavorites(request.getEnableFavorites());
        if (request.getAutoPrintReceipt() != null) s.setAutoPrintReceipt(request.getAutoPrintReceipt());
        if (request.getReceiptShowCustomer() != null) s.setReceiptShowCustomer(request.getReceiptShowCustomer());
        if (request.getReceiptShowBarcode() != null) s.setReceiptShowBarcode(request.getReceiptShowBarcode());
        if (request.getReceiptPaperWidth() != null) s.setReceiptPaperWidth(request.getReceiptPaperWidth());
        if (request.getRequireDiscountReason() != null) s.setRequireDiscountReason(request.getRequireDiscountReason());
        if (request.getRequirePinForPos() != null) s.setRequirePinForPos(request.getRequirePinForPos());
        if (request.getEnableKitchenDisplay() != null) s.setEnableKitchenDisplay(request.getEnableKitchenDisplay());
        if (request.getKitchenPrinterName() != null) s.setKitchenPrinterName(request.getKitchenPrinterName());
        if (request.getLowStockAlert() != null) s.setLowStockAlert(request.getLowStockAlert());
        if (request.getLowStockAlertEmail() != null) s.setLowStockAlertEmail(request.getLowStockAlertEmail());
        repository.save(s);
        return getPosSettings();
    }

    // ── Discount presets ──────────────────────────────────────────────────────

    public SettingsDtos.DiscountPresetsResponse getDiscountPresets() {
        BusinessSettings s = getOrCreateBusinessSettings();
        String raw = s.getDiscountPresets();
        SettingsDtos.DiscountPresetsResponse resp = new SettingsDtos.DiscountPresetsResponse();
        resp.setRequireReason(s.isRequireDiscountReason());
        if (raw == null || raw.isBlank()) {
            resp.setPresets(defaultDiscountPresets());
            return resp;
        }
        try {
            List<SettingsDtos.DiscountPresetItem> presets = objectMapper.readValue(raw,
                    objectMapper.getTypeFactory().constructCollectionType(List.class, SettingsDtos.DiscountPresetItem.class));
            resp.setPresets(presets);
        } catch (Exception ex) {
            log.warn("Failed to parse discount presets, using defaults", ex);
            resp.setPresets(defaultDiscountPresets());
        }
        return resp;
    }

    @Transactional
    public SettingsDtos.DiscountPresetsResponse updateDiscountPresets(SettingsDtos.DiscountPresetsRequest request) {
        BusinessSettings s = getOrCreateBusinessSettings();
        if (request.getPresets() != null) {
            s.setDiscountPresets(writeJson(request.getPresets()));
        }
        if (request.getRequireReason() != null) {
            s.setRequireDiscountReason(request.getRequireReason());
        }
        repository.save(s);
        return getDiscountPresets();
    }

    private List<SettingsDtos.DiscountPresetItem> defaultDiscountPresets() {
        return java.util.List.of(
            discountPreset("10% Off", 10.0, 0.0),
            discountPreset("15% Off", 15.0, 0.0),
            discountPreset("20% Off", 20.0, 0.0),
            discountPreset("50% Off", 50.0, 0.0),
            discountPreset("$1 Off", 0.0, 1.0),
            discountPreset("$5 Off", 0.0, 5.0)
        );
    }

    private SettingsDtos.DiscountPresetItem discountPreset(String label, double percent, double amount) {
        SettingsDtos.DiscountPresetItem item = new SettingsDtos.DiscountPresetItem();
        item.setLabel(label);
        item.setPercent(percent);
        item.setAmount(java.math.BigDecimal.valueOf(amount));
        return item;
    }

    private String normalizeLanguage(String language) {
        return "en".equalsIgnoreCase(language) ? "en" : "km";
    }

    private java.util.Optional<BusinessSettings> findSettingsRecord() {
        return repository.findFirstByOrderByIdAsc();
    }

    private InvoiceSettings getOrCreateInvoiceSettings() {
        InvoiceSettings settings = invoiceSettingsRepository.findAll().stream().findFirst().orElse(null);
        if (settings == null) {
            InvoiceSettings def = new InvoiceSettings();
            def.setPrefix("INV");
            def.setNextNumber(1L);
            def.setFooter("Thank you for your purchase");
            def.setShowTax(true);
            def.setShowKhqr(true);
            def.setDefaultInvoiceFormat("STANDARD");
            def.setDefaultReceiptFormat("THERMAL");
            settings = invoiceSettingsRepository.save(def);
        }
        return settings;
    }
}
