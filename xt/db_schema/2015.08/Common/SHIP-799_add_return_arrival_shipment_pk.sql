-- Add primary key link_return_arrival__shipment

BEGIN;
    ALTER TABLE link_return_arrival__shipment
        ADD PRIMARY KEY (return_arrival_id, shipment_id);

    -- Also make sure this row gets deleted if we delete its linked
    -- return_arrival
    ALTER TABLE link_return_arrival__shipment
        DROP CONSTRAINT link_return_arrival__shipment_return_arrival_id_fkey,
        ADD FOREIGN KEY (return_arrival_id) REFERENCES return_arrival(id)
        ON DELETE CASCADE
    ;
COMMIT;
