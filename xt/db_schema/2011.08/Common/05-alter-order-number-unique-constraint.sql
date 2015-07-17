-- Becuase Jimmy Choo orders will have conflicting order numbers, change the
-- unique constraint on order number to a unique composite key with channel_id

BEGIN;

    ALTER TABLE ONLY public.orders
        DROP CONSTRAINT unique_order_nr;

    ALTER TABLE ONLY public.orders
        ADD CONSTRAINT unique_order_nr UNIQUE (order_nr, channel_id);

COMMIT;
