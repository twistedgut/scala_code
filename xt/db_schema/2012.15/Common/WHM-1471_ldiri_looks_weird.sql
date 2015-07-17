-- Make this a proper link table, not a half-hearted attempt

BEGIN;
    DELETE FROM link_delivery_item__return_item WHERE return_item_id is null;
    ALTER TABLE link_delivery_item__return_item ALTER return_item_id SET NOT NULL;
COMMIT;
