# Kaknnea POS UI Review & Loyverse-Inspired Refactoring Plan

## 1. Current UI Review

### Strengths
- Material 3 design system with Riverpod state management
- Clean split-panel layout (cart sidebar + product grid)
- Responsive product grid with auto column calculation
- Swipe-to-delete with undo on cart items
- Multi-language support (Khmer/English)
- Offline mode support
- Held tickets functionality

### Issues Found

| # | Issue | Severity | File(s) |
|---|-------|----------|---------|
| 1 | **Inconsistent color palette** — Teal primary, green POS header, blue accent in cart panel. No unified color identity. | High | `main.dart`, `pos_header.dart`, `cart_panel.dart`, `app_config.dart` |
| 2 | **Two separate widget systems** — Legacy widgets in `lib/pos/` and newer ones in `lib/features/pos/` with duplicated logic | High | Multiple files |
| 3 | **Rough payment screen** — Basic two-step flow, no payment method selection (cash/card), no quick-cash amounts | High | `payment_screen.dart` |
| 4 | **Emoji-only icons** — Product placeholders use emoji instead of consistent icon system | Medium | `product_card.dart` |
| 5 | **No order mode indicator in cart** — Dine-in/Takeaway/Delivery mode selected in header but not shown in cart panel | Medium | `cart_panel.dart` |
| 6 | **Green POS header clashes with teal theme** — `Colors.green.shade700` vs `#0F766E` teal | Medium | `pos_header.dart` |
| 7 | **Cart items lack visual polish** — No separators, inconsistent padding, dense layout | Medium | `cart_items_list.dart`, `cart_item_widget.dart` |
| 8 | **No keyboard shortcuts / quick actions bar** for advanced cashiers | Low | — |
| 9 | **Category tabs horizontal in screen, no visual feedback** on active state | Low | `category_tabs.dart` |
| 10 | **Status bar underused** — Could show shift info, staff name, connection status in a cleaner way | Low | `status_bar.dart` |

---

## 2. Loyverse Design Analysis

From [loyverse.com](https://loyverse.com/), their design language is:

### Color Palette
- **Primary**: Loyverse Green (`#4CAF50` / green-500)
- **Backgrounds**: Clean white (`#FFFFFF`) with subtle grey (`#F5F5F5`)
- **Text**: Dark grey (`#333333`) for readability
- **Accents**: Blue (`#2196F3`) for interactive elements, Red for errors
- **Borders/Divider**: Very light grey (`#E0E0E0`)

### Layout Principles
- **Clean, uncluttered** — Lots of whitespace, minimal borders
- **Card-based** — White cards with subtle elevation (`box-shadow: 0 1px 3px rgba(0,0,0,0.1)`)
- **Clear visual hierarchy** — Total is prominent, items are scannable
- **Bottom-anchored actions** — Charge/Checkout button always visible at bottom of cart

### POS Screen Structure (from Help Center screenshots)
1. **Top bar**: Store name, date/time, shift status, settings
2. **Left panel** (or main area on mobile): Product grid with:
   - Horizontal category pills at top
   - Square product tiles with image + name + price
3. **Right panel** (cart/ticket):
   - Cart header with item count
   - Scrollable item list with qty controls
   - Totals section (Subtotal, Tax, Total)
   - Action row (Hold, Discount, Clear)
   - **Prominent "Charge $X.XX" button** — always visible, green
4. **Payment modal**: Clean dialog with payment method selection (Cash, Card, etc.), quick cash amounts

### Typography
- Clean sans-serif (system font)
- Bold for totals and product names
- Regular for descriptions and secondary info
- Monospace for amounts (optional)

---

## 3. Refactoring Plan

### Phase 1: Theme & Color System
- Unify to Loyverse-inspired green palette
- Standardize on white/grey backgrounds
- Create consistent border radius, shadow, and spacing tokens

### Phase 2: POS Screen Core Components
- Refactor `PosScreen` layout
- Redesign `ProductCard` with cleaner Loyverse style
- Redesign `CategoryTabs` as horizontal pills
- Refactor `CartPanel` with cleaner header and sections

### Phase 3: Cart & Checkout
- Cleaner `CartItemsList` with better visual separation
- Refactor `CartTotals` with Loyverse-style totals and prominent Charge button
- Add payment method selection to payment flow
- Add quick cash amount buttons

### Phase 4: Remaining Screens
- Clean up `LoginScreen` with Loyverse branding
- Standardize `PosHeader` / `StatusBar`

---

## 4. Implementation

See the following files for the refactored implementation:
- `lib/core/config/pos_theme.dart` — Unified theme tokens
- `lib/features/pos/widgets/product_card.dart` — Redesigned product card
- `lib/features/pos/widgets/category_tabs.dart` — Redesigned category pills
- `lib/features/pos/widgets/cart_panel.dart` — Refactored cart panel
- `lib/features/pos/widgets/cart_items_list.dart` — Cleaner cart items
- `lib/features/pos/widgets/cart_totals.dart` — Loyverse-style totals + Charge
- `lib/features/pos/screens/payment_screen.dart` — Full payment flow
- `lib/features/pos/screens/pos_screen.dart` — Updated main POS screen
- `lib/features/pos/widgets/pos_header.dart` — Clean header
