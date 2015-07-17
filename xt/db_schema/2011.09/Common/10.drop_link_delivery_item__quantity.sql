-- Drop public.link_delivery_item__quantity table as rows only seem to get inserted into it by a method which is never called.
-- Also it has no rows.
-- Also Ben can't explain what it's for.

BEGIN;
    DROP TABLE public.link_delivery_item__quantity;
COMMIT;
