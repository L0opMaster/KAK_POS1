-- ============================================================
-- V78: DEMO BUSINESS DATA — Kaknnea Food & Beverage Co.
-- Phnom Penh, Cambodia · Mixed Retail + Restaurant supply
-- All inserts use INSERT IGNORE for idempotency (skip on dup)
-- ============================================================

-- ─── PRODUCT CATEGORIES ──────────────────────────────────────
INSERT IGNORE INTO categories (id, name_en, name_km, display_order, active, created_at) VALUES
(1,  'Beverages',          'គ្រឿងផឹក',               1,  true, NOW()),
(2,  'Hot Drinks',         'គ្រឿងផឹកក្តៅ',            2,  true, NOW()),
(3,  'Cold Drinks',        'គ្រឿងផឹកត្រជាក់',          3,  true, NOW()),
(4,  'Fresh Juice',        'ទឹកផ្លែឈើស្រស់',           4,  true, NOW()),
(5,  'Food',               'អាហារ',                  10, true, NOW()),
(6,  'Rice Dishes',        'ម្ហូបបាយ',               11, true, NOW()),
(7,  'Noodles & Soup',     'មីសុប',                  12, true, NOW()),
(8,  'Starters & Snacks',  'មុខម្ហូបចាប់ផ្តើម',        13, true, NOW()),
(9,  'Desserts',           'បង្អែម',                 14, true, NOW()),
(10, 'Frozen & Packaged',  'ចំណីកក និងវេចខ្ចប់',       20, true, NOW()),
(11, 'Packaging',          'សម្ភារៈវេចខ្ចប់',           21, true, NOW());

-- ─── SUPPLIERS ───────────────────────────────────────────────
INSERT IGNORE INTO suppliers
  (name, contact_person, phone, email, address, payment_terms, lead_time_days,
   tax_id, default_currency, active, notes, created_at)
VALUES
('Heng Coffee Distributor',   'Heng Sokha',    '+855 12 345 001', 'heng@coffee.kh',
 'St. 271, Tuol Kork, Phnom Penh', 'Net 15', 3, 'TAX-KH-001', 'KHR', true,
 'Main supplier for green and roasted coffee beans', NOW()),

('Cambodia Fresh Produce',    'Chantha Ly',    '+855 12 345 002', 'fresh@cambo.kh',
 'Kandal Market, Phnom Penh', 'COD', 1, 'TAX-KH-002', 'KHR', true,
 'Daily delivery of fruits and vegetables', NOW()),

('Angkor Beverage Co.',       'Piseth Morn',   '+855 12 345 003', 'angkor@bev.kh',
 'St. 217, Sen Sok, Phnom Penh', 'Net 30', 5, 'TAX-KH-003', 'KHR', true,
 'Distributor for soft drinks, energy drinks, and water', NOW()),

('Phnom Penh Dairy',          'Sokun Keo',     '+855 12 345 004', 'dairy@ppd.kh',
 'Chroy Changvar, Phnom Penh', 'Net 7',  2, 'TAX-KH-004', 'KHR', true,
 'Fresh milk, condensed milk, and dairy products', NOW()),

('Thai Import Trading',        'Vannak Rin',    '+855 12 345 005', 'thai@import.kh',
 'Steung Meanchey, Phnom Penh', 'Net 30', 7, 'TAX-KH-005', 'USD', true,
 'Imported condiments, sauces, and packaged Thai goods', NOW()),

('KH Packaging Supplies',     'Ratana Chan',   '+855 12 345 006', 'pack@khsupply.kh',
 'Por Senchey, Phnom Penh', 'Net 15', 4, 'TAX-KH-006', 'KHR', true,
 'Cups, lids, straws, takeaway boxes, and bags', NOW()),

('Mekong Frozen Foods',       'Sophal Dara',   '+855 12 345 007', 'mekong@frozen.kh',
 'Russey Keo, Phnom Penh', 'Net 14', 3, 'TAX-KH-007', 'KHR', true,
 'Frozen meatballs, fish balls, sausages, and dim sum', NOW()),

('Golden Rice Mill',          'Bunthan Vuth',  '+855 12 345 008', 'golden@rice.kh',
 'Kampong Speu Province', 'Net 30', 7, 'TAX-KH-008', 'KHR', true,
 'Premium jasmine and broken rice supplier', NOW()),

('Siem Reap Honey & Herbs',   'Bopha Srey',    '+855 12 345 009', 'honey@siemreap.kh',
 'Siem Reap City', 'COD', 3, 'TAX-KH-009', 'KHR', true,
 'Natural honey, herbs, and spices', NOW()),

('PP Paper & Print Co.',      'Virak Noun',    '+855 12 345 010', 'paper@ppprint.kh',
 'Daun Penh, Phnom Penh', 'Net 15', 2, 'TAX-KH-010', 'KHR', true,
 'Receipt paper rolls, labels, and printed packaging', NOW());

-- ─── CUSTOMERS ───────────────────────────────────────────────
INSERT IGNORE INTO customers
  (customer_code, type, status, name_en, name_km, display_name,
   phone, email, address, payment_terms, credit_limit, active, created_at)
VALUES
('CUST-0001', 'RETAIL',     'ACTIVE', 'Walk-in Customer', 'អតិថិជនទូទៅ',  'Walk-in',
 NULL, NULL, NULL, NULL, 0, true, NOW()),

('CUST-0002', 'INDIVIDUAL', 'ACTIVE', 'Sophea Nguon',     'ង៉ោន សុភា',    'Sophea',
 '+855 12 111 001', 'sophea@gmail.com', 'BKK1, Phnom Penh', NULL, 500000, true, NOW()),

('CUST-0003', 'INDIVIDUAL', 'ACTIVE', 'Dara Chan',        'ចាន់ ដារ៉ា',    'Dara',
 '+855 12 111 002', 'dara@gmail.com', 'Toul Tom Poung, Phnom Penh', NULL, 200000, true, NOW()),

('CUST-0004', 'INDIVIDUAL', 'ACTIVE', 'Mony Pich',        'ពេជ្រ ម៉ូនី',   'Mony',
 '+855 12 111 003', NULL, 'Daun Penh, Phnom Penh', NULL, 0, true, NOW()),

('CUST-0005', 'BUSINESS',   'ACTIVE', 'Lotus Restaurant', 'ភោជនីយដ្ឋានឡូតុស', 'Lotus',
 '+855 23 222 001', 'order@lotus.kh', 'St. 51, Phnom Penh', 'Net 30', 5000000, true, NOW()),

('CUST-0006', 'BUSINESS',   'ACTIVE', 'Golden Star Hotel', 'សណ្ឋាគារ ហ្គោលដិននស្ថា', 'Golden Star',
 '+855 23 222 002', 'fb@goldenstar.kh', 'Sisowath Quay, Phnom Penh', 'Net 15', 10000000, true, NOW()),

('CUST-0007', 'BUSINESS',   'ACTIVE', 'Khmer Kitchen Co.','ហាង Khmer Kitchen', 'Khmer Kitchen',
 '+855 12 333 001', 'buy@khmerkitchen.kh', 'Russian Market, Phnom Penh', 'Net 15', 3000000, true, NOW()),

('CUST-0008', 'WHOLESALE',  'ACTIVE', 'Borey Café Chain', 'ហាងកាហ្វេ Borey', 'Borey Café',
 '+855 12 333 002', 'supply@boreycafe.kh', 'Toul Kork, Phnom Penh', 'Net 30', 8000000, true, NOW()),

('CUST-0009', 'WHOLESALE',  'ACTIVE', 'SenSok Canteen',   'បាយ SenSok',    'SenSok',
 '+855 12 333 003', NULL, 'Sen Sok, Phnom Penh', 'Net 7', 2000000, true, NOW()),

('CUST-0010', 'INDIVIDUAL', 'ACTIVE', 'Leakena Ros',      'រស់ លក្ខិណា',   'Leakena',
 '+855 12 111 010', 'leakena@gmail.com', 'Chamkar Mon, Phnom Penh', NULL, 0, true, NOW()),

('CUST-0011', 'INDIVIDUAL', 'ACTIVE', 'Vibol Ke',         'កែ វិបុល',      'Vibol',
 '+855 12 111 011', NULL, NULL, NULL, 0, true, NOW()),

('CUST-0012', 'BUSINESS',   'ACTIVE', 'PP Night Market',  'ផ្សារព្រឹកទីក្រុង', 'Night Market',
 '+855 23 444 001', NULL, 'Riverside, Phnom Penh', 'COD', 1000000, true, NOW()),

('CUST-0013', 'RETAIL',     'ACTIVE', 'Sothea Lim',       'លីម សុធា',      'Sothea',
 '+855 12 111 013', NULL, 'Meanchey, Phnom Penh', NULL, 0, true, NOW()),

('CUST-0014', 'BUSINESS',   'ACTIVE', 'Green Garden Resort','រីសត Green Garden','Green Garden',
 '+855 63 555 001', 'order@gg-resort.kh', 'Siem Reap', 'Net 30', 15000000, true, NOW()),

('CUST-0015', 'WHOLESALE',  'ACTIVE', 'Asia Foods Import', 'Asia Foods',    'Asia Foods',
 '+855 23 666 001', 'buy@asiafoods.kh', 'Diamond Island, Phnom Penh', 'Net 30', 20000000, true, NOW()),

('CUST-0016', 'INDIVIDUAL', 'ACTIVE', 'Channary Ouk',     'អ៊ូក ចន្នារី',   'Channary',
 '+855 12 111 016', NULL, NULL, NULL, 0, true, NOW()),

('CUST-0017', 'INDIVIDUAL', 'ACTIVE', 'Bora Nhem',        'ណេម បូរ៉ា',     'Bora',
 '+855 12 111 017', NULL, NULL, NULL, 100000, true, NOW()),

('CUST-0018', 'BUSINESS',   'ACTIVE', 'Kampot Pepper House','Kampot Pepper','Kampot Pepper',
 '+855 12 777 001', 'order@kampotpepper.kh', 'Kampot Province', 'Net 15', 5000000, true, NOW()),

('CUST-0019', 'RETAIL',     'INACTIVE','Kim Hak Pov',     'ភូ គីមហ៊ាក់',   'Kim Hak',
 '+855 12 111 019', NULL, NULL, NULL, 0, true, NOW()),

('CUST-0020', 'WHOLESALE',  'ACTIVE', 'Chhay Trading Co.','ការជំនួញ Chhay', 'Chhay Trading',
 '+855 23 888 001', 'order@chhaytrade.kh', 'Dangkao, Phnom Penh', 'Net 30', 12000000, true, NOW());

-- ─── PRODUCTS ────────────────────────────────────────────────
-- Hot Drinks (cat 2)
INSERT IGNORE INTO products
  (sku, name_en, name_km, category_id, price, cost, sellable, purchasable,
   track_inventory, product_type, sale_unit_id, active, created_at)
VALUES
('BEV-HOT-001', 'Khmer Iced Coffee',        'កាហ្វេខ្មែរ',             2, 4000,  1500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('BEV-HOT-002', 'Black Coffee',             'កាហ្វេខ្មៅ',              2, 3000,  1000, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('BEV-HOT-003', 'Milk Tea (Hot)',            'តែដោះគោក្តៅ',            2, 5000,  1800, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('BEV-HOT-004', 'Green Tea (Hot)',           'តែបៃតងក្តៅ',             2, 4000,  1200, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('BEV-HOT-005', 'Hot Chocolate',            'ស្ករគ្រាប់ក្តៅ',           2, 6000,  2000, true, false, false, 'SALE_ITEM', 1, true, NOW()),

-- Cold Drinks (cat 3)
('BEV-CLD-001', 'Iced Milk Tea',            'តែដោះគោត្រជាក់',          3, 5000,  1800, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('BEV-CLD-002', 'Iced Lemon Tea',           'តែក្រូចឆ្មារ',             3, 4500,  1500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('BEV-CLD-003', 'Iced Matcha Latte',        'ម៉ាស្ចាឡាតេ',              3, 8000,  2500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('BEV-CLD-004', 'Brown Sugar Boba',         'ទឹកស្ករត្នោត',             3, 9000,  3000, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('BEV-CLD-005', 'Strawberry Smoothie',      'ស្ត្របឺរ្រីស្មូតទី',         3, 10000, 3500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('BEV-CLD-006', 'Coca-Cola (Can)',          'កូកា-កូឡា',                3, 3500,  2000, true, true,  true,  'SALE_ITEM', 1, true, NOW()),
('BEV-CLD-007', 'Angkor Beer (330ml)',      'បៀរអង្គរ',                 3, 5000,  3200, true, true,  true,  'SALE_ITEM', 1, true, NOW()),
('BEV-CLD-008', 'Mineral Water (500ml)',    'ទឹកសុទ្ធ',                 3, 2000,  800,  true, true,  true,  'SALE_ITEM', 1, true, NOW()),

-- Fresh Juice (cat 4)
('JUS-001',     'Fresh Mango Juice',         'ទឹកស្វាយ',                4, 7000,  2500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('JUS-002',     'Fresh Lemon Juice',         'ទឹកក្រូចឆ្មារ',            4, 5000,  1500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('JUS-003',     'Fresh Passion Fruit Juice', 'ទឹកស្ករគ្រាប់',            4, 7000,  2500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('JUS-004',     'Fresh Watermelon Juice',    'ទឹកក្រូចព្រីង',            4, 6000,  2000, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('JUS-005',     'Mixed Fruit Juice',         'ទឹកផ្លែឈើចម្រុះ',          4, 8000,  3000, true, false, false, 'SALE_ITEM', 1, true, NOW()),

-- Rice Dishes (cat 6)
('FOOD-R-001',  'Fried Rice with Chicken',   'បាយឆាមាន់',               6, 12000, 4000, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-R-002',  'Fried Rice with Beef',      'បាយឆាសាច់គោ',            6, 14000, 5000, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-R-003',  'Fried Rice with Shrimp',    'បាយឆាបង្គា',               6, 15000, 5500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-R-004',  'Steam Rice (Portion)',      'បាយស',                   6, 2000,  500,  true, false, false, 'SALE_ITEM', 1, true, NOW()),

-- Noodles & Soup (cat 7)
('FOOD-N-001',  'Beef Noodle Soup',          'គុយតាវសាច់គោ',            7, 14000, 5000, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-N-002',  'Chicken Noodle Soup',       'គុយតាវមាន់',               7, 12000, 4000, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-N-003',  'Phnom Penh Noodles',        'គុយតាវភ្នំពេញ',             7, 13000, 4500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-N-004',  'Tom Yum Soup',              'ស៊ុបតុំយ៉ំ',               7, 18000, 7000, true, false, false, 'SALE_ITEM', 1, true, NOW()),

-- Starters & Snacks (cat 8)
('FOOD-S-001',  'Spring Rolls (4 pcs)',      'នំចុះ ៤គ្រាប់',             8, 8000,  2500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-S-002',  'Fried Chicken Wings',       'ស្លាបមាន់ចៀន',             8, 15000, 6000, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-S-003',  'French Fries',             'បំពង់',                   8, 8000,  2500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-S-004',  'Steamed Dumplings (6 pcs)', 'ហ្វឺ ៦គ្រាប់',             8, 12000, 4000, true, false, false, 'SALE_ITEM', 1, true, NOW()),

-- Desserts (cat 9)
('FOOD-D-001',  'Khmer Mango Sticky Rice',  'បាយដំណើបស្វាយ',            9, 8000,  3000, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-D-002',  'Coconut Jelly',             'ស្ករពោត',                 9, 5000,  1500, true, false, false, 'SALE_ITEM', 1, true, NOW()),
('FOOD-D-003',  'Ice Cream (2 scoops)',      'ទឹកកករសផ្អែម ២គ្រាប់',      9, 9000,  3500, true, false, false, 'SALE_ITEM', 1, true, NOW()),

-- Frozen & Packaged (cat 10)
('FRZ-001',     'Beef Meatball 5kg Box',     'មីដំំ 5kg',                10, 85000,  55000, true, true, true, 'SALE_ITEM', 2, true, NOW()),
('FRZ-002',     'Fish Ball 5kg Box',         'ពងត្រី 5kg',               10, 76000,  48000, true, true, true, 'SALE_ITEM', 2, true, NOW()),
('FRZ-003',     'Frozen Meatball 1kg Pack',  'មីដំំ 1kg',                10, 15000,  10000, true, true, true, 'SALE_ITEM', 4, true, NOW()),
('FRZ-004',     'Pork Sausage (10 pcs)',     'សាច់គ្រូបបបែររ 10 pc',      10, 18000,  12000, true, true, true, 'SALE_ITEM', 4, true, NOW()),
('FRZ-005',     'Shrimp Dumpling (20 pcs)',  'ហ្វឺបង្គា 20 pc',           10, 22000,  14000, true, true, true, 'SALE_ITEM', 4, true, NOW()),

-- Packaging (cat 11)
('PKG-001',     'Takeaway Cup 16oz (50pcs)', 'ពែងតូច 16oz 50 pc',        11, 18000, 12000, true, true, true, 'SALE_ITEM', 4, true, NOW()),
('PKG-002',     'Takeaway Box Medium',       'ប្រអប់',                   11, 8000,  5000,  true, true, true, 'SALE_ITEM', 4, true, NOW()),
('PKG-003',     'Straw Pack (100 pcs)',      'ចំបើង 100 pc',              11, 5000,  3000,  true, true, true, 'SALE_ITEM', 4, true, NOW()),
('PKG-004',     'Paper Bag (50 pcs)',        'ថង់ 50 pc',                11, 12000, 7000,  true, true, true, 'SALE_ITEM', 4, true, NOW());

-- ─── MODIFIER GROUPS ─────────────────────────────────────────
INSERT IGNORE INTO modifier_groups (id, name_en, name_km, required, multi_select, active, display_order, created_at)
VALUES
(1, 'Size',         'ទំហំ',           true,  false, true, 1, NOW()),
(2, 'Sugar Level',  'កម្រិតស្ករ',      false, false, true, 2, NOW()),
(3, 'Ice Level',    'កម្រិតទឹកកក',     false, false, true, 3, NOW()),
(4, 'Add-ons',      'បន្ថែម',          false, true,  true, 4, NOW()),
(5, 'Cooking Style','របៀបចំអិន',       false, false, true, 5, NOW());

-- ─── MODIFIER OPTIONS ────────────────────────────────────────
-- Column aliases on first SELECT row are required so JOIN can reference v.grp, v.name_en, etc.
INSERT IGNORE INTO modifier_options (group_id, name_en, name_km, price_delta, active, display_order, created_at)
SELECT g.id, v.name_en, v.name_km, v.price_delta, true, v.display_order, NOW()
FROM modifier_groups g
JOIN (
  -- Size options
  SELECT 'Size' AS grp, 'Small (S)'    AS name_en, 'តូច'          AS name_km, -1000 AS price_delta, 1 AS display_order UNION ALL
  SELECT 'Size',        'Medium (M)',               'មធ្យម',          0,                             2 UNION ALL
  SELECT 'Size',        'Large (L)',                'ធំ',            2000,                           3 UNION ALL
  SELECT 'Size',        'X-Large (XL)',             'ធំខ្លាំង',       4000,                           4 UNION ALL
  -- Sugar Level
  SELECT 'Sugar Level', '0% (No Sugar)',   'គ្មានស្ករ',      0, 1 UNION ALL
  SELECT 'Sugar Level', '25% (Light)',     'ស្ករតិច',        0, 2 UNION ALL
  SELECT 'Sugar Level', '50% (Half)',      'ស្ករពាក់',       0, 3 UNION ALL
  SELECT 'Sugar Level', '75% (Less Sweet)','ស្ករច្រើនតិច',   0, 4 UNION ALL
  SELECT 'Sugar Level', '100% (Full)',     'ស្ករពេញ',        0, 5 UNION ALL
  -- Ice Level
  SELECT 'Ice Level', 'No Ice',      'គ្មានទឹកកក',   0, 1 UNION ALL
  SELECT 'Ice Level', 'Less Ice',    'ទឹកកកតិច',    0, 2 UNION ALL
  SELECT 'Ice Level', 'Normal Ice',  'ទឹកកកធម្មតា',  0, 3 UNION ALL
  SELECT 'Ice Level', 'Extra Ice',   'ទឹកកកច្រើន',   0, 4 UNION ALL
  -- Add-ons
  SELECT 'Add-ons', 'Extra Espresso Shot', 'កាហ្វេបន្ថែម',  3000, 1 UNION ALL
  SELECT 'Add-ons', 'Tapioca Pearls',      'គ្រាប់',         2000, 2 UNION ALL
  SELECT 'Add-ons', 'Aloe Vera',           'អាឡូវ៉េរ៉ា',     2000, 3 UNION ALL
  SELECT 'Add-ons', 'Grass Jelly',         'ជ្រក់',          2000, 4 UNION ALL
  SELECT 'Add-ons', 'Coconut Jelly',       'ដូង',            2000, 5 UNION ALL
  -- Cooking Style
  SELECT 'Cooking Style', 'Well Done', 'ឆ្អិនស្ងួត',  0,    1 UNION ALL
  SELECT 'Cooking Style', 'Medium',    'ឆ្អិតក្លែក',  0,    2 UNION ALL
  SELECT 'Cooking Style', 'Steamed',   'ចំហុយ',       0,    3 UNION ALL
  SELECT 'Cooking Style', 'Grilled',   'អាំង',        1000, 4
) v ON g.name_en = v.grp
WHERE NOT EXISTS (
  SELECT 1 FROM modifier_options mo
  WHERE mo.group_id = g.id AND mo.name_en = v.name_en
);

-- ─── RESTAURANT TABLES ───────────────────────────────────────
INSERT IGNORE INTO `tables` (id, table_number, display_name, capacity, section, status, is_active, notes, created_at)
VALUES
(1,  'T1',  'Table 1',    4, 'INDOOR',  'AVAILABLE', true, NULL,                   NOW()),
(2,  'T2',  'Table 2',    4, 'INDOOR',  'AVAILABLE', true, NULL,                   NOW()),
(3,  'T3',  'Table 3',    4, 'INDOOR',  'AVAILABLE', true, NULL,                   NOW()),
(4,  'T4',  'Table 4',    6, 'INDOOR',  'AVAILABLE', true, NULL,                   NOW()),
(5,  'T5',  'Table 5',    6, 'INDOOR',  'AVAILABLE', true, NULL,                   NOW()),
(6,  'O1',  'Outdoor 1',  4, 'OUTDOOR', 'AVAILABLE', true, NULL,                   NOW()),
(7,  'O2',  'Outdoor 2',  4, 'OUTDOOR', 'AVAILABLE', true, NULL,                   NOW()),
(8,  'V1',  'VIP Room',   8, 'VIP',     'AVAILABLE', true, 'Private dining room',  NOW()),
(9,  'T6',  'Table 6',    2, 'INDOOR',  'AVAILABLE', true, 'Window seat',          NOW()),
(10, 'T7',  'Table 7',    2, 'INDOOR',  'AVAILABLE', true, 'Window seat',          NOW()),
(11, 'T8',  'Table 8',    4, 'INDOOR',  'AVAILABLE', true, NULL,                   NOW()),
(12, 'B1',  'Bar 1',      2, 'BAR',     'AVAILABLE', true, 'Bar counter seat',     NOW()),
(13, 'B2',  'Bar 2',      2, 'BAR',     'AVAILABLE', true, 'Bar counter seat',     NOW()),
(14, 'O3',  'Outdoor 3',  6, 'OUTDOOR', 'AVAILABLE', true, 'Garden area',          NOW()),
(15, 'V2',  'VIP Room 2', 10,'VIP',     'AVAILABLE', true, 'Large private room',   NOW());
