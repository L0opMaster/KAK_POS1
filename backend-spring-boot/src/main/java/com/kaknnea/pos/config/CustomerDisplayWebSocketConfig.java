package com.kaknnea.pos.config;


import com.kaknnea.pos.websocket.CustomerDisplayWebSocketHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class CustomerDisplayWebSocketConfig implements WebSocketConfigurer {
    private final CustomerDisplayWebSocketHandler customerDisplayWebSocketHandler;

    @Override
    public void registerWebSocketHandlers(
            WebSocketHandlerRegistry registry
    ) {
        registry
                .addHandler(
                        customerDisplayWebSocketHandler,
                        "/ws/customer-display"
                )
                // Restrict this to your deployed app origins in production.
                .setAllowedOriginPatterns("*");
    }
}
