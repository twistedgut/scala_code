-- new custom list types for back office usability
BEGIN;

    INSERT INTO product.attribute_type (id, name, web_attribute, navigational) VALUES (10, 'Marketing List', 'CUSTOM_LIST', false);
    INSERT INTO product.attribute_type (id, name, web_attribute, navigational) VALUES (11, 'Press List', 'CUSTOM_LIST', false);
    INSERT INTO product.attribute_type (id, name, web_attribute, navigational) VALUES (12, 'Fashion Advisor List', 'CUSTOM_LIST', false);
    INSERT INTO product.attribute_type (id, name, web_attribute, navigational) VALUES (13, 'Editorial List', 'CUSTOM_LIST', false);
    INSERT INTO product.attribute_type (id, name, web_attribute, navigational) VALUES (14, 'Personal Shopping List', 'CUSTOM_LIST', false);
    INSERT INTO product.attribute_type (id, name, web_attribute, navigational) VALUES (15, 'Product Merchandising List', 'CUSTOM_LIST', false);
    INSERT INTO product.attribute_type (id, name, web_attribute, navigational) VALUES (16, 'Buying List', 'CUSTOM_LIST', false);
    INSERT INTO product.attribute_type (id, name, web_attribute, navigational) VALUES (17, 'Merchandising List', 'CUSTOM_LIST', false);

COMMIT;

