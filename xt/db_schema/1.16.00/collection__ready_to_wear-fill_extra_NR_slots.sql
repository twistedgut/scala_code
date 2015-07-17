-- when we added extra slots on the worklist we didn't extend the NR filling

BEGIN;

    -- fill the last 4 slots with NR
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        9,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='XX'),
        true
    )
    ;
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        10,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='XX'),
        true
    )
    ;
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        11,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='XX'),
        true
    )
    ;
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        12,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='XX'),
        true
    )
    ;

COMMIT;
