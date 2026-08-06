package com.kaknnea.pos;

import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Utility class to generate bcrypt hashes for passwords.
 * Run with: mvn exec:java@generate-hash -Dpassword="YourPassword"
 */
public class HashGenerator {
    public static void main(String[] args) {
        String password = System.getProperty("password", "Password123!");
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        String hash = encoder.encode(password);
        System.out.println("Password: " + password);
        System.out.println("Hash: " + hash);
    }
}
