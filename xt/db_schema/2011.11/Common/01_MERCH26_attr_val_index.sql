-- Create index for product.attribute_value table (attribute_id column)
BEGIN;
    CREATE INDEX idx_product_attribute_value__attribute_id ON product.attribute_value (attribute_id);
COMMIT;