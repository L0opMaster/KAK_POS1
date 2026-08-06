package com.kaknnea.pos.websocket;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import org.springframework.web.util.UriComponentsBuilder;

import java.io.IOException;
import java.net.URI;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.regex.Pattern;

/**
 * Relays decoded barcode values from a phone camera to one active POS client.
 *
 * The relay never reads or writes a cart. The POS client receives the barcode
 * and adds the product through its existing local-cart notifier.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ScannerRelayWebSocketHandler extends TextWebSocketHandler {
    private static final Pattern SESSION_CODE_PATTERN =
            Pattern.compile("^[A-Z2-9]{8}$");
    private static final int MAX_BARCODE_LENGTH = 128;

    private static final String SESSION_CODE_ATTRIBUTE = "scannerSessionCode";
    private static final String ROLE_ATTRIBUTE = "scannerRole";

    private final ObjectMapper objectMapper;
    private final ConcurrentMap<String, ScannerRoom> rooms =
            new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session)
            throws Exception {
        ConnectionRequest request = parseConnectionRequest(session.getUri());

        if (request == null) {
            session.close(new CloseStatus(
                    1008,
                    "Expected session and role query parameters"
            ));
            return;
        }

        session.getAttributes().put(
                SESSION_CODE_ATTRIBUTE,
                request.sessionCode()
        );
        session.getAttributes().put(ROLE_ATTRIBUTE, request.role());

        ScannerRoom room = rooms.computeIfAbsent(
                request.sessionCode(),
                ignored -> new ScannerRoom()
        );

        WebSocketSession safeSession =
                new ConcurrentWebSocketSessionDecorator(
                        session,
                        5_000,
                        16 * 1024
                );

        synchronized (room) {
            if ("pos".equals(request.role())) {
                if (isOpen(room.pos)) {
                    session.close(new CloseStatus(
                            1008,
                            "A POS is already using this session"
                    ));
                    return;
                }

                room.pos = safeSession;
                sendJson(room.pos, Map.of(
                        "type", "ready",
                        "role", "pos",
                        "session", request.sessionCode()
                ));

                if (isOpen(room.scanner)) {
                    sendJson(room.pos, Map.of(
                            "type", "scanner_connected"
                    ));
                }
                return;
            }

            // A phone can join only after the POS created the room.
            if (!isOpen(room.pos)) {
                session.close(new CloseStatus(
                        1008,
                        "POS session not found"
                ));
                removeRoomIfEmpty(request.sessionCode(), room);
                return;
            }

            if (isOpen(room.scanner)) {
                session.close(new CloseStatus(
                        1008,
                        "A phone scanner is already connected"
                ));
                return;
            }

            room.scanner = safeSession;
            sendJson(room.scanner, Map.of(
                    "type", "ready",
                    "role", "scanner",
                    "session", request.sessionCode()
            ));
            sendJson(room.pos, Map.of("type", "scanner_connected"));
        }

        log.info(
                "Phone scanner connected to POS session {}",
                request.sessionCode()
        );
    }

    @Override
    protected void handleTextMessage(
            WebSocketSession session,
            TextMessage message
    ) throws Exception {
        String role = (String) session.getAttributes().get(ROLE_ATTRIBUTE);
        String sessionCode =
                (String) session.getAttributes().get(SESSION_CODE_ATTRIBUTE);

        if (!"scanner".equals(role) || sessionCode == null) {
            sendJson(session, Map.of(
                    "type", "error",
                    "message", "Only the phone scanner can send barcodes"
            ));
            return;
        }

        if (message.getPayloadLength() > 512) {
            sendJson(session, Map.of(
                    "type", "error",
                    "message", "Scanner message is too large"
            ));
            return;
        }

        JsonNode body;
        try {
            body = objectMapper.readTree(message.getPayload());
        } catch (Exception exception) {
            sendJson(session, Map.of(
                    "type", "error",
                    "message", "Invalid scanner message"
            ));
            return;
        }

        if (!"barcode".equals(body.path("type").asText())) {
            sendJson(session, Map.of(
                    "type", "error",
                    "message", "Unsupported scanner message type"
            ));
            return;
        }

        String value = body.path("value").asText("").trim();
        if (!isValidBarcode(value)) {
            sendJson(session, Map.of(
                    "type", "error",
                    "message", "Barcode must contain 1 to 128 characters"
            ));
            return;
        }

        ScannerRoom room = rooms.get(sessionCode);
        if (room == null || !isOpen(room.pos)) {
            sendJson(session, Map.of(
                    "type", "error",
                    "message", "POS is disconnected"
            ));
            return;
        }

        sendJson(room.pos, Map.of(
                "type", "barcode",
                "value", value,
                "receivedAt", Instant.now().toString()
        ));
        sendJson(session, Map.of(
                "type", "barcode_ack",
                "value", value
        ));
    }

    @Override
    public void afterConnectionClosed(
            WebSocketSession session,
            CloseStatus status
    ) {
        String sessionCode =
                (String) session.getAttributes().get(SESSION_CODE_ATTRIBUTE);
        String role = (String) session.getAttributes().get(ROLE_ATTRIBUTE);

        if (sessionCode == null || role == null) {
            return;
        }

        ScannerRoom room = rooms.get(sessionCode);
        if (room == null) {
            return;
        }

        synchronized (room) {
            if ("pos".equals(role)
                    && sameSession(room.pos, session)) {
                room.pos = null;
                sendJsonQuietly(room.scanner, Map.of(
                        "type", "pos_disconnected"
                ));
            } else if ("scanner".equals(role)
                    && sameSession(room.scanner, session)) {
                room.scanner = null;
                sendJsonQuietly(room.pos, Map.of(
                        "type", "scanner_disconnected"
                ));
            }
        }

        removeRoomIfEmpty(sessionCode, room);
    }

    @Override
    public void handleTransportError(
            WebSocketSession session,
            Throwable exception
    ) throws Exception {
        log.debug(
                "Scanner relay transport error for {}: {}",
                session.getId(),
                exception.getMessage()
        );
        if (session.isOpen()) {
            session.close(CloseStatus.SERVER_ERROR);
        }
    }

    private ConnectionRequest parseConnectionRequest(URI uri) {
        if (uri == null) {
            return null;
        }

        var parameters = UriComponentsBuilder
                .fromUri(uri)
                .build()
                .getQueryParams();

        String sessionCode = parameters.getFirst("session");
        String role = parameters.getFirst("role");

        if (sessionCode == null || role == null) {
            return null;
        }

        sessionCode = sessionCode.trim().toUpperCase();
        role = role.trim().toLowerCase();

        if (!SESSION_CODE_PATTERN.matcher(sessionCode).matches()) {
            return null;
        }

        if (!"pos".equals(role) && !"scanner".equals(role)) {
            return null;
        }

        return new ConnectionRequest(sessionCode, role);
    }

    private boolean isValidBarcode(String value) {
        return value != null
                && !value.isBlank()
                && value.length() <= MAX_BARCODE_LENGTH
                && value.chars().noneMatch(Character::isISOControl);
    }

    private boolean isOpen(WebSocketSession session) {
        return session != null && session.isOpen();
    }

    private boolean sameSession(
            WebSocketSession stored,
            WebSocketSession closed
    ) {
        return stored != null
                && stored.getId().equals(closed.getId());
    }

    private void sendJson(
            WebSocketSession session,
            Map<String, ?> payload
    ) throws IOException {
        if (isOpen(session)) {
            session.sendMessage(new TextMessage(
                    objectMapper.writeValueAsString(payload)
            ));
        }
    }

    private void sendJsonQuietly(
            WebSocketSession session,
            Map<String, ?> payload
    ) {
        try {
            sendJson(session, payload);
        } catch (Exception exception) {
            log.debug(
                    "Could not send scanner relay status: {}",
                    exception.getMessage()
            );
        }
    }

    private void removeRoomIfEmpty(
            String sessionCode,
            ScannerRoom room
    ) {
        synchronized (room) {
            if (!isOpen(room.pos) && !isOpen(room.scanner)) {
                rooms.remove(sessionCode, room);
            }
        }
    }

    private record ConnectionRequest(String sessionCode, String role) {
    }

    private static final class ScannerRoom {
        private WebSocketSession pos;
        private WebSocketSession scanner;
    }
}
