package com.kaknnea.pos.websocket;

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
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.regex.Pattern;

/**
 * Relays live cart/checkout JSON from the POS register to a paired
 * customer-facing display device.
 *
 * The relay never parses the payload the POS sends beyond checking it is
 * valid JSON — the message schema (cart_update, payment_pending, ...) is
 * owned entirely by the two Flutter apps, not the backend.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CustomerDisplayWebSocketHandler extends TextWebSocketHandler {
    private static final Pattern SESSION_CODE_PATTERN =
            Pattern.compile("^[A-Z2-9]{8}$");
    private static final int MAX_MESSAGE_LENGTH = 8 * 1024;

    private static final String SESSION_CODE_ATTRIBUTE = "displaySessionCode";
    private static final String ROLE_ATTRIBUTE = "displayRole";

    private final ObjectMapper objectMapper;
    private final ConcurrentMap<String, DisplayRoom> rooms =
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

        DisplayRoom room = rooms.computeIfAbsent(
                request.sessionCode(),
                ignored -> new DisplayRoom()
        );

        WebSocketSession safeSession =
                new ConcurrentWebSocketSessionDecorator(
                        session,
                        5_000,
                        32 * 1024
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

                if (isOpen(room.display)) {
                    sendJson(room.pos, Map.of(
                            "type", "display_connected"
                    ));
                }
                return;
            }

            // A display can join only after the POS created the room.
            if (!isOpen(room.pos)) {
                session.close(new CloseStatus(
                        1008,
                        "POS session not found"
                ));
                removeRoomIfEmpty(request.sessionCode(), room);
                return;
            }

            if (isOpen(room.display)) {
                session.close(new CloseStatus(
                        1008,
                        "A customer display is already connected"
                ));
                return;
            }

            room.display = safeSession;
            sendJson(room.display, Map.of(
                    "type", "ready",
                    "role", "display",
                    "session", request.sessionCode()
            ));
            sendJson(room.pos, Map.of("type", "display_connected"));
        }

        log.info(
                "Customer display connected to POS session {}",
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

        if (!"pos".equals(role) || sessionCode == null) {
            sendJson(session, Map.of(
                    "type", "error",
                    "message", "Only the register can send display updates"
            ));
            return;
        }

        if (message.getPayloadLength() > MAX_MESSAGE_LENGTH) {
            sendJson(session, Map.of(
                    "type", "error",
                    "message", "Display message is too large"
            ));
            return;
        }

        try {
            objectMapper.readTree(message.getPayload());
        } catch (Exception exception) {
            sendJson(session, Map.of(
                    "type", "error",
                    "message", "Invalid display message"
            ));
            return;
        }

        DisplayRoom room = rooms.get(sessionCode);
        if (room == null || !isOpen(room.display)) {
            // No display connected — silently drop, the POS keeps working
            // offline from the display's perspective.
            return;
        }

        room.display.sendMessage(message);
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

        DisplayRoom room = rooms.get(sessionCode);
        if (room == null) {
            return;
        }

        synchronized (room) {
            if ("pos".equals(role)
                    && sameSession(room.pos, session)) {
                room.pos = null;
                sendJsonQuietly(room.display, Map.of(
                        "type", "pos_disconnected"
                ));
            } else if ("display".equals(role)
                    && sameSession(room.display, session)) {
                room.display = null;
                sendJsonQuietly(room.pos, Map.of(
                        "type", "display_disconnected"
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
                "Customer display relay transport error for {}: {}",
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

        if (!"pos".equals(role) && !"display".equals(role)) {
            return null;
        }

        return new ConnectionRequest(sessionCode, role);
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
                    "Could not send customer display relay status: {}",
                    exception.getMessage()
            );
        }
    }

    private void removeRoomIfEmpty(
            String sessionCode,
            DisplayRoom room
    ) {
        synchronized (room) {
            if (!isOpen(room.pos) && !isOpen(room.display)) {
                rooms.remove(sessionCode, room);
            }
        }
    }

    private record ConnectionRequest(String sessionCode, String role) {
    }

    private static final class DisplayRoom {
        private WebSocketSession pos;
        private WebSocketSession display;
    }
}
