-- Add MRP algorithms for sorting product on website

BEGIN;

CREATE OR REPLACE FUNCTION add_mrp_sort_orders()
RETURNS VOID AS $$
DECLARE
    available_id INTEGER;
    age_id INTEGER;
    in_stock_id INTEGER;
    inverse_price_id INTEGER;
    main_id INTEGER;

    operator_id INTEGER;
    mrp_id INTEGER;

BEGIN
    SELECT id INTO available_id FROM product.pws_sort_variable WHERE name='available_to_sell';
    SELECT id INTO age_id FROM product.pws_sort_variable WHERE name='inverse_upload_days';
    SELECT id INTO in_stock_id FROM product.pws_sort_variable WHERE name='pcnt_sizes_in_stock';
    SELECT id INTO main_id FROM product.pws_sort_destination WHERE name='main';

    SELECT id INTO mrp_id FROM channel WHERE name='MRPORTER.COM';
    SELECT id INTO operator_id FROM operator WHERE username='d.jokilehto';

    INSERT INTO product.pws_sort_variable ( name, description, created_by )
        VALUES ( 'inverse_price', 'Inverse Price', operator_id )
        RETURNING id INTO inverse_price_id
    ;

    INSERT INTO product.pws_sort_variable_weighting
        ( pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by, channel_id )
    VALUES
        ( available_id, 40, main_id, operator_id, mrp_id ),
        ( inverse_price_id, 30, main_id, operator_id, mrp_id ),
        ( in_stock_id, 20, main_id, operator_id, mrp_id ),
        ( age_id, 10, main_id, operator_id, mrp_id )
    ;
END;
$$ LANGUAGE plpgsql;

SELECT add_mrp_sort_orders();
DROP FUNCTION add_mrp_sort_orders();

COMMIT;
