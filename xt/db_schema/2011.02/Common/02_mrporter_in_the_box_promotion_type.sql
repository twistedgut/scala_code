BEGIN;

INSERT INTO promotion_type (
    name, product_type, weight, fabric, origin, hs_code
) VALUES (
    'MR PORTER Postcard',
    'Postcard',
    '0.05',
    '100% paper',
    'United Kingdom',
    '490900'
);


COMMIT;
