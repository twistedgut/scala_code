BEGIN;

INSERT INTO product.storage_type (name, description) VALUES ('Cage', 'Items of high value');

UPDATE product 
   SET storage_type_id = (SELECT id FROM product.storage_type WHERE name = 'Cage')
 WHERE id IN (
              SELECT product.id 
                FROM product
                JOIN variant ON product.id = variant.product_id
                JOIN quantity ON variant.id = quantity.variant_id  
                JOIN location ON location.id = quantity.location_id
               WHERE location.location like '021Y%'
          )
;

COMMIT;
