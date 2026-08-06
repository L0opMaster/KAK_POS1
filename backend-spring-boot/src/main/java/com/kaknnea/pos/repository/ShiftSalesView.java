package com.kaknnea.pos.repository;

import java.math.BigDecimal;

public interface ShiftSalesView {
    BigDecimal getTotal();
    long getCount();
}
