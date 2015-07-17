-- CANDO-1159: Add New EIP Customer Categories

BEGIN WORK;

-- Reset the Sequence Id on the Table
SELECT SETVAL( 'customer_category_id_seq', ( SELECT MAX(id) FROM customer_category ) );

-- Insert the New Categories
INSERT INTO customer_category (category,customer_class_id,fast_track) VALUES (
    'EIP FoundersCard',
    ( SELECT id FROM customer_class WHERE class = 'EIP' ),
    TRUE
);
INSERT INTO customer_category (category,customer_class_id,fast_track) VALUES (
    'EIP Mastercard',
    ( SELECT id FROM customer_class WHERE class = 'EIP' ),
    TRUE
);
INSERT INTO customer_category (category,customer_class_id,fast_track) VALUES (
    'EIP Elite',
    ( SELECT id FROM customer_class WHERE class = 'EIP' ),
    TRUE
);

COMMIT WORK;
