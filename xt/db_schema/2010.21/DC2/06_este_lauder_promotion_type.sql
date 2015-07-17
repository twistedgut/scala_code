BEGIN;

INSERT INTO promotion_type
(name,product_type,weight,fabric,origin,hs_code,promotion_class_id)
VALUES (
    'Este Lauder Brochure', 
    'Brochures - not for resale', 
    '0.70', 
    '100% paper', 
    'USA', 
    '4901.99', 
    '2'
);

COMMIT;
