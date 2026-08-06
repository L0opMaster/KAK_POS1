package com.kaknnea.pos.config;


import com.kaknnea.pos.websocket.ScannerRelayWebSocketHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class ScannerWebSocketConfig implements WebSocketConfigurer {
    private final ScannerRelayWebSocketHandler scannerRelayWebSocketHandler;

    @Override
    public void registerWebSocketHandlers(
            WebSocketHandlerRegistry registry
    ) {
        registry
                .addHandler(
                        scannerRelayWebSocketHandler,
                        "/ws/scanner"
                )
                // Restrict this to your deployed app origins in production.
                .setAllowedOriginPatterns("*");
    }
}
