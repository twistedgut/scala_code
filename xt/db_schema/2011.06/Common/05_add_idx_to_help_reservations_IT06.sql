-- Add Indexes to help the Reservation pages

BEGIN WORK;

-- Add an Index for the 'product_id' field on the Stock Order table
CREATE INDEX idx_stock_order_product_id ON stock_order (product_id);
CREATE INDEX idx_stock_order_voucher_product_id ON stock_order (voucher_product_id);

-- Add an Index for the 'operator_id' field on the 'reservation' table
CREATE INDEX idx_public_reservation__operator_id ON reservation (operator_id);

-- Add an Index for the 'season_id' field on the 'product' table
CREATE INDEX idx_public_product__season_id ON product ( season_id );

COMMIT WORK;
