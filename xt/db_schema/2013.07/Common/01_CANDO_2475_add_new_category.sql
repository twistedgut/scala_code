-- CANDO-2475: Add New Customer Category : 'Hot Contact - Client Relations'

BEGIN WORK;

-- Reset the Sequence Id on the Table
SELECT SETVAL( 'customer_category_id_seq', ( SELECT MAX(id) FROM customer_category ) );

-- Insert New Category
INSERT INTO customer_category (category,customer_class_id,fast_track) VALUES (
    'Hot Contact - Client Relations',
    ( SELECT id FROM customer_class WHERE class = 'None' ),
    FALSE
);

COMMIT WORK;

