-- Add a foreign key to reservation(customer_id), and delete any rows that
-- reference non-existent customers

BEGIN;
    -- Delete log rows associated with reservations referencing non-existent
    -- customers
    DELETE FROM reservation_log rl USING reservation r
        WHERE rl.reservation_id = r.id
          AND NOT EXISTS ( SELECT id FROM customer c WHERE r.customer_id = c.id );

    -- Delete reservations referencing non-existent customers
    DELETE FROM reservation r
        WHERE NOT EXISTS ( SELECT id FROM customer c WHERE r.customer_id = c.id );

    -- Add a default value
    ALTER TABLE reservation ALTER COLUMN date_created SET DEFAULT now();

    -- Add foreign key relation
    ALTER TABLE reservation ADD FOREIGN KEY (customer_id) REFERENCES public.customer(id);
COMMIT;
