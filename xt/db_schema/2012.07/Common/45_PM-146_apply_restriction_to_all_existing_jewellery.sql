BEGIN;

-- find all products with the type Jewellery, Jewelry, Fine Jewellery and apply the
-- new "Jewellery" restriction.

INSERT INTO link_product__ship_restriction (product_id, ship_restriction_id) (
    SELECT id, (SELECT id FROM ship_restriction WHERE title='Jewellery')
    FROM product WHERE product_type_id IN (
        SELECT id FROM product_type WHERE product_type IN ('Fine Jewelry', 'Jewellery', 'Jewelry' )
    )
);

COMMIT;
