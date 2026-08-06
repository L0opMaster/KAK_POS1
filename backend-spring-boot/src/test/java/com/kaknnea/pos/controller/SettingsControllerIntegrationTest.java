package com.kaknnea.pos.controller;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class SettingsControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithMockUser(authorities = "PERM_SETTINGS_MANAGE")
    void generalAndCompanyProfileEndpoints_roundTrip() throws Exception {
        mockMvc.perform(get("/api/settings/general"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.defaultLanguage").exists())
                .andExpect(jsonPath("$.currency").exists())
                .andExpect(jsonPath("$.requireShiftForSales", is(true)));

        mockMvc.perform(put("/api/settings/general")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "defaultLanguage": "km",
                                  "currency": "KHR",
                                  "receiptFooter": "Thank you",
                                  "defaultInvoiceFormat": "STANDARD",
                                  "defaultReceiptFormat": "THERMAL",
                                  "showKhqr": true,
                                  "requireShiftForSales": false
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.requireShiftForSales", is(false)));

        mockMvc.perform(put("/api/settings/company-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "businessName": "KAKNNEA Test HQ",
                                  "logoUrl": "/media/logo.png",
                                  "address": "Phnom Penh",
                                  "phone": "+855 12 345 678",
                                  "receiptFooter": "Thank you"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.businessName", is("KAKNNEA Test HQ")))
                .andExpect(jsonPath("$.logoUrl", is("/media/logo.png")));

        mockMvc.perform(put("/api/settings/tax")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "taxRate": 10.5,
                                  "showTax": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.taxRate", is(10.5)))
                .andExpect(jsonPath("$.showTax", is(true)));

        mockMvc.perform(get("/api/settings/business"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.businessName", is("KAKNNEA Test HQ")))
                .andExpect(jsonPath("$.taxRate", is(10.5)))
                .andExpect(jsonPath("$.requireShiftForSales", is(false)));
    }

    @Test
    @WithMockUser(authorities = "PERM_SETTINGS_MANAGE")
    void paymentMethodsCurrenciesAndUnitsEndpoints_work() throws Exception {
        mockMvc.perform(get("/api/settings/payment-methods"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(greaterThanOrEqualTo(1))));

        String createdPaymentMethod = mockMvc.perform(post("/api/settings/payment-methods")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "KHQR",
                                  "name": "KHQR Wallet",
                                  "displayOrder": 55,
                                  "cash": false,
                                  "active": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code", is("KHQR")))
                .andExpect(jsonPath("$.name", is("KHQR Wallet")))
                .andReturn()
                .getResponse()
                .getContentAsString();

        Number paymentMethodIdValue = com.jayway.jsonpath.JsonPath.read(createdPaymentMethod, "$.id");
        long paymentMethodId = paymentMethodIdValue.longValue();

        mockMvc.perform(get("/api/settings/payment-methods/" + paymentMethodId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code", is("KHQR")));

        mockMvc.perform(patch("/api/settings/payment-methods/" + paymentMethodId + "/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "active": false
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active", is(false)));

        mockMvc.perform(get("/api/settings/currencies"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(greaterThanOrEqualTo(1))));

        String createdCurrency = mockMvc.perform(post("/api/settings/currencies")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "THB",
                                  "name": "Thai Baht",
                                  "symbol": "฿",
                                  "exchangeRate": 0.008500,
                                  "displayOrder": 30,
                                  "defaultCurrency": false,
                                  "active": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code", is("THB")))
                .andReturn()
                .getResponse()
                .getContentAsString();

        Number currencyIdValue = com.jayway.jsonpath.JsonPath.read(createdCurrency, "$.id");
        long currencyId = currencyIdValue.longValue();

        mockMvc.perform(get("/api/settings/currencies/" + currencyId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code", is("THB")));

        mockMvc.perform(patch("/api/settings/currencies/" + currencyId + "/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "active": false
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active", is(false)));

        mockMvc.perform(get("/api/settings/units"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThanOrEqualTo(1))));
    }

    @Test
    @WithMockUser(authorities = "PERM_SETTINGS_MANAGE")
    void unitCrudEndpoints_work() throws Exception {
        String createdUnit = mockMvc.perform(post("/api/units")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "ZZ_BOX_TEST",
                                  "nameEn": "Box Test",
                                  "nameKm": "ប្រអប់សាកល្បង",
                                  "symbol": "bxt",
                                  "baseUnitGroup": "COUNT",
                                  "baseUnit": true,
                                  "conversionFactor": 1,
                                  "active": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code", is("ZZ_BOX_TEST")))
                .andExpect(jsonPath("$.nameEn", is("Box Test")))
                .andReturn()
                .getResponse()
                .getContentAsString();

        Number unitIdValue = com.jayway.jsonpath.JsonPath.read(createdUnit, "$.id");
        long unitId = unitIdValue.longValue();

        mockMvc.perform(get("/api/units?q=ZZ_BOX_TEST&page=0&size=10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(greaterThanOrEqualTo(1))));

        mockMvc.perform(get("/api/units/" + unitId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nameEn", is("Box Test")))
                .andExpect(jsonPath("$.nameKm", is("ប្រអប់សាកល្បង")));

        mockMvc.perform(put("/api/units/" + unitId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "ZZ_BOX_TEST_2",
                                  "nameEn": "Storage Box",
                                  "nameKm": "ប្រអប់ស្តុក",
                                  "symbol": "box",
                                  "baseUnitGroup": "COUNT",
                                  "baseUnit": true,
                                  "conversionFactor": 1,
                                  "active": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nameEn", is("Storage Box")))
                .andExpect(jsonPath("$.nameKm", is("ប្រអប់ស្តុក")));

        mockMvc.perform(patch("/api/units/" + unitId + "/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "active": false
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active", is(false)));
    }

    @Test
    @WithMockUser(authorities = "PERM_SETTINGS_MANAGE")
    void printersEndpoint_updatesInvoiceCompatibilityModel() throws Exception {
        mockMvc.perform(put("/api/settings/printers")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "printerName": "Epson TM-T20",
                                  "printerType": "NETWORK",
                                  "printerAddress": "192.168.0.25:9100",
                                  "defaultInvoiceFormat": "STANDARD",
                                  "defaultReceiptFormat": "THERMAL",
                                  "invoicePrefix": "REC",
                                  "nextInvoiceNumber": 42,
                                  "invoiceFooter": "Printed by system"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.printerName", is("Epson TM-T20")))
                .andExpect(jsonPath("$.invoicePrefix", is("REC")))
                .andExpect(jsonPath("$.nextInvoiceNumber", is(42)));

        mockMvc.perform(get("/api/settings/invoice"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.printerType", is("NETWORK")))
                .andExpect(jsonPath("$.prefix", is("REC")))
                .andExpect(jsonPath("$.nextNumber", is(42)));
    }

    @Test
    @WithMockUser(authorities = "PERM_SETTINGS_MANAGE")
    void posLayoutAndOpenTicketEndpoints_roundTrip() throws Exception {
        mockMvc.perform(get("/api/settings/pos-layout"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.preset").exists())
                .andExpect(jsonPath("$.quickActions", hasSize(greaterThanOrEqualTo(1))))
                .andExpect(jsonPath("$.menuSections", hasSize(greaterThanOrEqualTo(1))));

        mockMvc.perform(get("/api/settings/open-tickets"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enableOpenTickets", is(true)))
                .andExpect(jsonPath("$.predefinedTicketPrefix", is("T")));

        mockMvc.perform(put("/api/settings/pos-layout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "preset": "LOYVERSE_CAFE",
                                  "defaultMode": "TAKEAWAY",
                                  "showBarcode": true,
                                  "showCustomerPanel": true,
                                  "showHeldSales": true,
                                  "showTables": false,
                                  "showProductionInAdmin": true,
                                  "quickActions": [
                                    {
                                      "id": "charge",
                                      "label": "Charge",
                                      "icon": "payments",
                                      "enabled": true,
                                      "order": 10,
                                      "visibleInRestaurant": true,
                                      "visibleInRetail": true
                                    }
                                  ],
                                  "menuSections": [
                                    {
                                      "id": "sale",
                                      "label": "Sale",
                                      "icon": "point_of_sale",
                                      "enabled": true,
                                      "order": 10
                                    }
                                  ],
                                  "categoryPresentation": []
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.preset", is("LOYVERSE_CAFE")))
                .andExpect(jsonPath("$.defaultMode", is("TAKEAWAY")))
                .andExpect(jsonPath("$.showTables", is(false)));

        mockMvc.perform(put("/api/settings/open-tickets")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "enableOpenTickets": true,
                                  "enableTables": false,
                                  "enableSplitMerge": true,
                                  "enableTransfer": false,
                                  "predefinedTicketPrefix": "B"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enableTables", is(false)))
                .andExpect(jsonPath("$.enableTransfer", is(false)))
                .andExpect(jsonPath("$.predefinedTicketPrefix", is("B")));
    }

    @Test
    @WithMockUser(authorities = "PERM_SETTINGS_MANAGE")
    void importTemplateEndpoint_returnsCsvAttachment() throws Exception {
        mockMvc.perform(get("/api/settings/import-templates/products"))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Disposition", is("attachment; filename=\"products-template.csv\"")))
                .andExpect(content().contentType("text/csv"))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("sku,barcode,nameEn")));
    }

    @Test
    @WithMockUser(authorities = "PERM_SETTINGS_MANAGE")
    void partialGeneralAndTaxUpdates_doNotClearBooleanFlagsWhenOmitted() throws Exception {
        mockMvc.perform(put("/api/settings/general")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "defaultLanguage": "en",
                                  "currency": "USD",
                                  "showKhqr": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.showKhqr", is(true)));

        mockMvc.perform(put("/api/settings/general")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "receiptFooter": "Updated footer only"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.showKhqr", is(true)));

        mockMvc.perform(put("/api/settings/tax")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "taxRate": 7.5,
                                  "showTax": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.showTax", is(true)));

        mockMvc.perform(put("/api/settings/tax")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "taxRate": 8.0
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.showTax", is(true)));
    }

    @Test
    @WithMockUser(authorities = "PERM_SETTINGS_MANAGE")
    void duplicateCodesAndMissingDeletes_returnControlledErrors() throws Exception {
        mockMvc.perform(post("/api/settings/payment-methods")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "ABA",
                                  "name": "ABA Pay",
                                  "displayOrder": 10,
                                  "cash": false,
                                  "active": true
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/settings/payment-methods")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "aba",
                                  "name": "Duplicate ABA",
                                  "displayOrder": 20,
                                  "cash": false,
                                  "active": true
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Payment method code already exists")));

        mockMvc.perform(post("/api/settings/currencies")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "SGD",
                                  "name": "Singapore Dollar",
                                  "symbol": "S$",
                                  "exchangeRate": 1.0,
                                  "displayOrder": 10,
                                  "defaultCurrency": false,
                                  "active": true
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/settings/currencies")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "sgd",
                                  "name": "Duplicate Singapore Dollar",
                                  "symbol": "S$",
                                  "exchangeRate": 1.0,
                                  "displayOrder": 20,
                                  "defaultCurrency": false,
                                  "active": true
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Currency code already exists")));

        mockMvc.perform(patch("/api/settings/payment-methods/999999/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "active": false
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Payment method not found")));
    }
}
