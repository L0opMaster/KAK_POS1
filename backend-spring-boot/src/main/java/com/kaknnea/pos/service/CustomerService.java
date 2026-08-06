package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Customer;
import com.kaknnea.pos.domain.CustomerCreditAccount;
import com.kaknnea.pos.domain.Payment;
import com.kaknnea.pos.dto.CustomerDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.mapper.CustomerMapper;
import com.kaknnea.pos.repository.CustomerCreditAccountRepository;
import com.kaknnea.pos.repository.CustomerCreditOpeningBalanceRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.PaymentRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.util.DocumentNumberUtil;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Locale;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class CustomerService {
    private final CustomerRepository customerRepository;
    private final CustomerMapper customerMapper;
    private final SaleRepository saleRepository;
    private final CustomerCreditAccountRepository creditAccountRepository;
    private final CreditCollectionService creditCollectionService;
    private final CustomerCreditOpeningBalanceRepository openingBalanceRepository;
    private final PaymentRepository paymentRepository;

    public CustomerService(CustomerRepository customerRepository, CustomerMapper customerMapper,
            SaleRepository saleRepository, CustomerCreditAccountRepository creditAccountRepository,
            CreditCollectionService creditCollectionService,
            CustomerCreditOpeningBalanceRepository openingBalanceRepository,
            PaymentRepository paymentRepository) {
        this.customerRepository = customerRepository;
        this.customerMapper = customerMapper;
        this.saleRepository = saleRepository;
        this.creditAccountRepository = creditAccountRepository;
        this.creditCollectionService = creditCollectionService;
        this.openingBalanceRepository = openingBalanceRepository;
        this.paymentRepository = paymentRepository;
    }

    @Transactional(readOnly = true)
    public List<CustomerDtos.CustomerResponse> list(String q, String type, String status) {
        return search(q, type, status, 0, Math.max(200, (int) customerRepository.count()))
                .getContent();
    }

    @Transactional(readOnly = true)
    public Page<CustomerDtos.CustomerResponse> search(String q, String type, String status, int page, int size) {
        String normalizedQuery = q == null ? "" : q.trim();
        String normalizedType = normalizeText(type);
        String normalizedStatus = normalizeText(status);
        return customerRepository.search(normalizedQuery, normalizedType, normalizedStatus, PageRequest.of(page, size))
                .map(this::toCustomerResponse);
    }

    @Transactional(readOnly = true)
    public CustomerDtos.CustomerResponse getById(Long id) {
        creditCollectionService.synchronizeCustomerState(id);
        Customer customer = customerRepository.findById(id)
                .orElseThrow(() -> new ApiException("Customer not found"));
        return toCustomerResponse(customer);
    }

    @Transactional
    public CustomerDtos.CustomerResponse create(CustomerDtos.CustomerRequest request) {
        Customer customer = new Customer();
        applyRequest(customer, request, true);
        Customer saved = customerRepository.save(customer);
        ensureCreditAccount(saved);
        return toCustomerResponse(saved);
    }

    @Transactional
    public CustomerDtos.CustomerResponse update(Long id, CustomerDtos.CustomerRequest request) {
        Customer customer = customerRepository.findById(id).orElseThrow(() -> new ApiException("Customer not found"));
        applyRequest(customer, request, false);
        Customer saved = customerRepository.save(customer);
        ensureCreditAccount(saved);
        return toCustomerResponse(saved);
    }

    @Transactional
    public void delete(Long id) {
        Customer customer = customerRepository.findById(id)
                .orElseThrow(() -> new ApiException("Customer not found"));
        customerRepository.delete(customer);
    }

    private void ensureCreditAccount(Customer customer) {
        CustomerCreditAccount account = creditAccountRepository.findByCustomerId(customer.getId()).orElse(null);
        if (account == null) {
            account = new CustomerCreditAccount();
            account.setCustomer(customer);
        }
        account.setCreditLimit(customer.getCreditLimit());
        account.setBalance(customer.getCreditBalance());
        creditAccountRepository.save(account);
    }

    private CustomerDtos.CustomerResponse toCustomerResponse(Customer customer) {
        CustomerDtos.CustomerResponse response = customerMapper.toResponse(customer);
        response.setCode(customer.getCustomerCode());
        response.setStatus(customer.getStatus());
        response.setDisplayName(resolveDisplayName(customer));
        response.setCreatedAt(customer.getCreatedAt() != null ? customer.getCreatedAt().toString() : null);
        response.setUpdatedAt(customer.getUpdatedAt() != null ? customer.getUpdatedAt().toString() : null);
        BigDecimal totalSales = saleRepository.totalSalesByCustomerId(customer.getId());
        response.setTotalSales(totalSales == null ? BigDecimal.ZERO : totalSales);
        Instant lastPurchaseDate = saleRepository.latestPurchaseDateByCustomerId(customer.getId());
        response.setLastPurchaseDate(lastPurchaseDate != null ? lastPurchaseDate.toString() : null);
        BigDecimal openingBalance = openingBalanceRepository.sumOriginalAmountByCustomerId(customer.getId());
        response.setOpeningBalance(openingBalance == null ? BigDecimal.ZERO : openingBalance);
        paymentRepository.findCustomerOrSaleCustomerPaymentsByStatus(customer.getId(), Payment.PaymentStatus.COMPLETED)
                .stream()
                .findFirst()
                .map(Payment::getCreatedAt)
                .ifPresent(createdAt -> response.setLastPaymentDate(createdAt.toString()));
        response.setOverdue(saleRepository.existsByCustomerIdAndStatusAndCreditDueAtBefore(
                customer.getId(), "CREDIT", Instant.now()));
        return response;
    }

    private void applyRequest(Customer customer, CustomerDtos.CustomerRequest request, boolean createMode) {
        String displayName = firstNonBlank(request.getDisplayName(), request.getNameEn(), request.getNameKm());
        if (displayName == null) {
            throw new ApiException("At least one customer name is required");
        }
        String normalizedNameEn = firstNonBlank(request.getNameEn(), request.getDisplayName(), request.getNameKm());
        String normalizedNameKm = firstNonBlank(request.getNameKm(), request.getDisplayName(), request.getNameEn());
        String requestedCode = normalizeCode(request.getCode());
        if (createMode) {
            customer.setCustomerCode(requestedCode != null ? requestedCode : nextGeneratedCode());
        } else if (requestedCode != null && !requestedCode.equalsIgnoreCase(customer.getCustomerCode())) {
            customer.setCustomerCode(requestedCode);
        }
        ensureUniqueCode(customer.getCustomerCode(), customer.getId());

        customer.setType(firstNonBlank(normalizeText(request.getType()), "INDIVIDUAL"));
        customer.setStatus(firstNonBlank(normalizeText(request.getStatus()), "ACTIVE"));
        customer.setNameEn(normalizedNameEn);
        customer.setNameKm(normalizedNameKm);
        customer.setDisplayName(displayName);
        customer.setPhone(normalizeNullable(request.getPhone()));
        customer.setEmail(normalizeNullable(request.getEmail()));
        customer.setAddress(normalizeNullable(request.getAddress()));
        customer.setNotes(normalizeNullable(request.getNotes()));
        customer.setContactPerson(normalizeNullable(request.getContactPerson()));
        customer.setPaymentTerms(normalizeNullable(request.getPaymentTerms()));
        customer.setTaxNumber(normalizeNullable(request.getTaxNumber()));
        customer.setCreditLimit(request.getCreditLimit() == null ? BigDecimal.ZERO : request.getCreditLimit());
    }

    private void ensureUniqueCode(String code, Long currentId) {
        customerRepository.findByCustomerCode(code)
                .filter(existing -> currentId == null || !existing.getId().equals(currentId))
                .ifPresent(existing -> {
                    throw new ApiException("Customer code already exists");
                });
    }

    private String nextGeneratedCode() {
        long nextId = customerRepository.count() + 1;
        String candidate = String.format("CUST%05d", nextId);
        while (customerRepository.findByCustomerCode(candidate).isPresent()) {
            nextId += 1;
            candidate = String.format("CUST%05d", nextId);
        }
        return candidate;
    }

    private String resolveDisplayName(Customer customer) {
        return firstNonBlank(customer.getDisplayName(), customer.getNameEn(), customer.getNameKm(), customer.getCustomerCode(), "Customer");
    }

    private String normalizeCode(String value) {
        String normalized = normalizeNullable(value);
        return normalized == null ? null : normalized.toUpperCase(Locale.ROOT);
    }

    private String normalizeText(String value) {
        String normalized = normalizeNullable(value);
        return normalized == null ? null : normalized.toUpperCase(Locale.ROOT);
    }

    private String normalizeNullable(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            String normalized = normalizeNullable(value);
            if (normalized != null) {
                return normalized;
            }
        }
        return null;
    }

    @Transactional(readOnly = true)
    public List<CustomerDtos.CustomerSaleResponse> history(Long customerId) {
        creditCollectionService.synchronizeCustomerState(customerId);
        return saleRepository.findByCustomerId(customerId).stream().map(sale -> {
            CustomerDtos.CustomerSaleResponse resp = new CustomerDtos.CustomerSaleResponse();
            resp.setSaleId(sale.getId());
            boolean saleReceipt = isSaleReceiptSale(sale);
            resp.setDocumentType(saleReceipt ? "SALE_RECEIPT" : "INVOICE");
            resp.setDocumentNumber(saleReceipt
                    ? DocumentNumberUtil.saleReceiptNumber(sale)
                    : DocumentNumberUtil.saleNumber(sale));
            resp.setStatus(sale.getStatus());
            resp.setCreatedAt(sale.getCreatedAt() != null ? sale.getCreatedAt().toString() : null);
            resp.setUpdatedAt(sale.getUpdatedAt() != null ? sale.getUpdatedAt().toString() : null);
            resp.setCreditDueAt(sale.getCreditDueAt() != null ? sale.getCreditDueAt().toString() : null);
            resp.setGrandTotal(sale.getGrandTotal());
            resp.setPaidAmount(sale.getPaidAmount());
            resp.setPaymentTerms(sale.getPaymentTerms());
            resp.setShiftId(sale.getShift() != null ? sale.getShift().getId() : null);
            resp.setCashierName(sale.getCreatedBy() != null ? sale.getCreatedBy().getFullName() : null);
            return resp;
        }).collect(Collectors.toList());
    }

    private boolean isSaleReceiptSale(com.kaknnea.pos.domain.Sale sale) {
        if (sale == null) {
            return false;
        }
        String status = sale.getStatus() == null ? "" : sale.getStatus().toUpperCase(Locale.ROOT);
        String terms = sale.getPaymentTerms() == null ? "" : sale.getPaymentTerms().toUpperCase(Locale.ROOT);
        boolean receiptSource = sale.getShift() != null || "CASH".equals(terms);
        if (!receiptSource || "CREDIT".equals(status) || "DRAFT".equals(status) || "HOLD".equals(status)) {
            return false;
        }
        if ("REFUNDED".equals(status) || "PARTIALLY_REFUNDED".equals(status) || "VOID".equals(status)) {
            return true;
        }
        BigDecimal paid = sale.getPaidAmount() == null ? BigDecimal.ZERO : sale.getPaidAmount();
        BigDecimal total = sale.getGrandTotal() == null ? BigDecimal.ZERO : sale.getGrandTotal();
        return paid.compareTo(BigDecimal.ZERO) > 0 && paid.compareTo(total) >= 0;
    }
}
