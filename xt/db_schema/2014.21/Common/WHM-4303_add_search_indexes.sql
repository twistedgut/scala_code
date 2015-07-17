-- Add some indexes to improve search performance

BEGIN;
    CREATE INDEX ON orders (invoice_address_id);
COMMIT;
