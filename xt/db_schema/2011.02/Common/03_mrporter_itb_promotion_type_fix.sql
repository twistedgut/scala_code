BEGIN;

UPDATE promotion_type SET promotion_class_id = (
        SELECT id FROM promotion_class WHERE class = 'Free Gift'
    ) WHERE name = 'MR PORTER Postcard';


COMMIT;
