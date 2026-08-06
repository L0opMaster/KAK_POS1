package com.kaknnea.pos.dto;

import lombok.Data;

import java.util.List;

public class RolePermissionDtos {
    @Data
    public static class RolePermissionUpdate {
        private List<String> permissions;
    }
}
