-- Add index to channel_id on orders

BEGIN;
    CREATE INDEX orders_idx_channel_id ON orders (channel_id);
COMMIT
