package com.kaknnea.pos;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class KaknneaPosApplication {
    public static void main(String[] args) {
        SpringApplication.run(KaknneaPosApplication.class, args);
    }
}
