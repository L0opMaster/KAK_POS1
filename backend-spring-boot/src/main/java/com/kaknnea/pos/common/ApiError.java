package com.kaknnea.pos.common;

import lombok.Data;

@Data
public class ApiError {
    private int status;
    private String message;
    private String timestamp;
}