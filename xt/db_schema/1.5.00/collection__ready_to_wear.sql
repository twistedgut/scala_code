-- this is part of UPL-66; http://animal/browse/UPL-66

BEGIN;

    -- the collection
    INSERT INTO photography.image_collection
    (name)
    VALUES
    ('Ready To Wear')
    ;

    -- items and locations in the collection
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        2,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='FR'),
        false
    )
    ;
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        3,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='BK'),
        false
    )
    ;
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        4,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='OS'),
        false
    )
    ;
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        5,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='CU'),
        false
    )
    ;
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        6,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='XX'),
        true
    )
    ;
    INSERT INTO photography.image_collection_item
    (image_index, image_collection_id, image_label_id, set_not_required)
    VALUES (
        7,
        (SELECT id FROM photography.image_collection WHERE name='Ready To Wear'),
        (SELECT id FROM photography.image_label WHERE short_description='XX'),
        true
    )
    ;

COMMIT;
