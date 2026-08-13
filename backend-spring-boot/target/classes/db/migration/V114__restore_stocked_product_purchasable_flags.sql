-- Fixes "<product> is not allowed for purchasing" for products that
-- genuinely carry tracked stock (e.g. Donuts) but can no longer be added to
-- a Purchase Order.
--
-- History that caused this:
--   V38 added track_inventory (default FALSE).
--   V39 then reset track_inventory = FALSE for every active product,
--     including ones that already had real stock quantity (seeded in the
--     legacy `stocks` table, later carried into `stock_items` by V28).
--   V50 added purchasable (default FALSE) and tried to backfill it from
--     track_inventory, but its guard clause
--       WHERE sellable IS NULL OR purchasable IS NULL OR product_type IS NULL
--     can never be true on NOT NULL DEFAULT columns — MySQL backfills the
--     column default (FALSE), never NULL, when the column is added. That
--     UPDATE has been a no-op for every row since the day it ran.
--   PurchasingWorkflowService rejects a PO line unless BOTH purchasable
--     and track_inventory are true, so every product — including ones
--     that visibly carry stock — has been rejected ever since.
--
-- This does NOT mark every product purchasable (that was explicitly out
-- of scope). It only restores the two flags for products that have
-- current, positive stock_items quantity — the same signal that shows
-- they were always meant to be physically stocked, not made-to-order.
-- Already-applied migrations (V39, V50) are immutable and are not edited.

-- Products with real tracked stock that are NOT the output of a
-- manufacturing recipe (i.e. genuinely bought from a supplier, not
-- produced internally): restore both track_inventory and purchasable.
UPDATE products p
JOIN (
    SELECT product_id, SUM(quantity) AS total_qty
    FROM stock_items
    GROUP BY product_id
) si ON si.product_id = p.id
SET p.track_inventory = TRUE,
    p.purchasable = TRUE,
    p.product_type = 'STOCK_ITEM'
WHERE si.total_qty > 0
  AND p.track_inventory = FALSE
  AND p.id NOT IN (SELECT output_product_id FROM production_recipes);

-- Products with real tracked stock that ARE a recipe's manufactured
-- output: they are legitimately inventory-tracked (production increases
-- their stock), but not purchasable from a supplier — purchasable stays
-- FALSE; only track_inventory/product_type are restored.
UPDATE products p
JOIN (
    SELECT product_id, SUM(quantity) AS total_qty
    FROM stock_items
    GROUP BY product_id
) si ON si.product_id = p.id
SET p.track_inventory = TRUE,
    p.product_type = 'STOCK_ITEM'
WHERE si.total_qty > 0
  AND p.track_inventory = FALSE
  AND p.id IN (SELECT output_product_id FROM production_recipes);
