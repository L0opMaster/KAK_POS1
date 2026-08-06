package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.RestaurantTable;
import com.kaknnea.pos.domain.Sale;
import com.kaknnea.pos.domain.SaleLine;
import com.kaknnea.pos.domain.Product;
import com.kaknnea.pos.dto.HeldTicketDtos;
import com.kaknnea.pos.repository.PredefinedTicketRepository;
import com.kaknnea.pos.repository.CustomerRepository;
import com.kaknnea.pos.repository.ProductRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.ShiftRepository;
import com.kaknnea.pos.repository.TableRepository;
import com.kaknnea.pos.repository.TicketOperationLogRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HeldTicketServiceTest {

    @Mock
    private SaleRepository saleRepository;

    @Mock
    private ProductRepository productRepository;

    @Mock
    private CustomerRepository customerRepository;

    @Mock
    private ShiftRepository shiftRepository;

    @Mock
    private TableRepository tableRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private PredefinedTicketRepository predefinedTicketRepository;

    @Mock
    private TicketOperationLogRepository ticketOperationLogRepository;

    private ObjectMapper objectMapper = new ObjectMapper();

    @InjectMocks
    private HeldTicketService heldTicketService;

    @BeforeEach
    void setUp() {
        // Inject the ObjectMapper into the HeldTicketService
        heldTicketService.setObjectMapper(objectMapper);
    }

    @Test
    void list_includesTableNameInResponse() {
        // Arrange: create a sale with an associated table
        RestaurantTable table = new RestaurantTable();
        table.setTableNumber("A1");
        Sale sale = new Sale();
        sale.setId(100L);
        sale.setStatus("HOLD");
        sale.setTable(table);

        when(saleRepository.findOpenTickets(any()))
                .thenReturn(List.of(sale));

        // Act
        List<HeldTicketDtos.HeldTicketResponse> rs = heldTicketService.list(null, null, null);

        // Assert
        assertEquals(1, rs.size());
        assertEquals("A1", rs.get(0).getTableName());
    }

    @Test
    void list_returnsCartAliasForLegacyClients() {
        Product product = new Product();
        product.setId(7L);
        product.setSku("SKU-7");
        product.setNameEn("Coffee");
        product.setNameKm("កាហ្វេ");
        product.setBarcode("BC7");

        SaleLine line = new SaleLine();
        line.setId(10L);
        line.setProduct(product);
        line.setQuantity(BigDecimal.valueOf(2));
        line.setUnitPrice(BigDecimal.valueOf(1.5));
        line.setLineDiscount(BigDecimal.ZERO);

        Sale sale = new Sale();
        sale.setId(101L);
        sale.setStatus("HOLD");
        sale.setLines(List.of(line));

        when(saleRepository.findOpenTickets(any())).thenReturn(List.of(sale));

        List<HeldTicketDtos.HeldTicketResponse> rs = heldTicketService.list(null, null, null);

        assertEquals(1, rs.size());
        assertNotNull(rs.get(0).getItems());
        assertNotNull(rs.get(0).getCart());
        assertEquals(rs.get(0).getItems().size(), rs.get(0).getCart().size());
        assertEquals("Coffee", rs.get(0).getCart().get(0).getProduct().getNameEn());
    }

    @Test
    void upsert_setsTable_onRequestWithTableName() {
        // Arrange
        HeldTicketDtos.UpsertRequest req = new HeldTicketDtos.UpsertRequest();
        req.setStatus("HOLD");
        req.setTableName("B2");
        // provide a cashier id to bypass current actor lookup
        req.setCashierId(99L);
        // also supply a shift id so we don't call getCurrentActor for shifts
        req.setShiftId(123L);
        when(shiftRepository.findById(123L)).thenReturn(Optional.of(new com.kaknnea.pos.domain.Shift()));
        // empty item list required by validator
        req.setItems(List.of());

        RestaurantTable table = new RestaurantTable();
        table.setTableNumber("B2");
        when(tableRepository.findByTableNumber("B2"))
                .thenReturn(Optional.of(table));
        // stub cashier lookup
        when(userRepository.findById(99L)).thenReturn(Optional.of(new com.kaknnea.pos.domain.User()));

        when(saleRepository.save(any(Sale.class)))
                .thenAnswer(invocation -> {
                    Sale s = invocation.getArgument(0);
                    s.setId(55L);
                    return s;
                });

        // Act
        HeldTicketDtos.HeldTicketResponse resp;
        // security util is static; mock username and stub repository lookup so
        // logOperation does not fail
        try (var sec = org.mockito.Mockito.mockStatic(com.kaknnea.pos.util.SecurityUtil.class)) {
            sec.when(com.kaknnea.pos.util.SecurityUtil::currentUsername)
                    .thenReturn("dummyUser");
            when(userRepository.findByEmail("dummyUser"))
                    .thenReturn(Optional.of(new com.kaknnea.pos.domain.User()));

            // ensure logOperation doesn't NPE
            when(ticketOperationLogRepository.save(any()))
                    .thenAnswer(invocation -> {
                        com.kaknnea.pos.domain.TicketOperationLog log = invocation.getArgument(0);
                        log.setId(1L);
                        return log;
                    });
            resp = heldTicketService.upsert(req, null);
        }

        // Assert
        assertNotNull(resp);
        assertEquals("B2", resp.getTableName());
        verify(saleRepository, atLeastOnce()).save(any(Sale.class));
    }

    @Test
    void upsert_acceptsLegacyCartPayload() {
        HeldTicketDtos.ProductPayload product = new HeldTicketDtos.ProductPayload();
        product.setId(5L);
        product.setPrice(BigDecimal.valueOf(2.25));

        HeldTicketDtos.LineRequest line = new HeldTicketDtos.LineRequest();
        line.setQty(BigDecimal.ONE);
        line.setProduct(product);

        HeldTicketDtos.UpsertRequest req = new HeldTicketDtos.UpsertRequest();
        req.setStatus("open");
        req.setCashierId(99L);
        req.setShiftId(123L);
        req.setCart(List.of(line));

        when(shiftRepository.findById(123L)).thenReturn(Optional.of(new com.kaknnea.pos.domain.Shift()));
        when(userRepository.findById(99L)).thenReturn(Optional.of(new com.kaknnea.pos.domain.User()));
        when(productRepository.findById(5L)).thenReturn(Optional.of(new Product()));
        when(saleRepository.save(any(Sale.class)))
                .thenAnswer(invocation -> {
                    Sale s = invocation.getArgument(0);
                    s.setId(77L);
                    return s;
                });

        try (var sec = org.mockito.Mockito.mockStatic(com.kaknnea.pos.util.SecurityUtil.class)) {
            sec.when(com.kaknnea.pos.util.SecurityUtil::currentUsername).thenReturn("dummyUser");
            when(userRepository.findByEmail("dummyUser"))
                    .thenReturn(Optional.of(new com.kaknnea.pos.domain.User()));
            when(ticketOperationLogRepository.save(any()))
                    .thenAnswer(invocation -> {
                        com.kaknnea.pos.domain.TicketOperationLog log = invocation.getArgument(0);
                        log.setId(1L);
                        return log;
                    });

            HeldTicketDtos.HeldTicketResponse resp = heldTicketService.upsert(req, null);

            assertNotNull(resp);
            assertEquals("HOLD", resp.getStatus());
            assertNotNull(resp.getCart());
            assertEquals(1, resp.getCart().size());
        }
    }
}
