-- CREATE OUTNET ROOT NODES FOR CATEGORY MANAGEMENT
-- INCLUDING A SHOP ATTRIBUTE FOR OUTNET

BEGIN WORK;

INSERT INTO product.attribute VALUES (default,'Shop',0,false,'',false,null,3);

INSERT INTO product.attribute VALUES (default,'Clothing',1,false,'',false,null,3);
INSERT INTO product.attribute VALUES (default,'Shoes',1,false,'',false,null,3);
INSERT INTO product.attribute VALUES (default,'Unknown',1,false,'',false,null,3);

-- SHOP PARENT NODE
INSERT INTO product.navigation_tree VALUES (default,(SELECT id FROM product.attribute WHERE channel_id = 3 AND name = 'Shop' AND attribute_type_id = 0),null,1,false,false,null,'');

-- ROOT NODES
INSERT INTO product.navigation_tree VALUES (default,(SELECT id FROM product.attribute WHERE channel_id = 3 AND name = 'Clothing'),(SELECT id FROM product.navigation_tree WHERE attribute_id = (SELECT id FROM product.attribute WHERE channel_id = 3 AND name = 'Shop' AND attribute_type_id = 0)),1,true,false,null,'');
INSERT INTO product.navigation_tree VALUES (default,(SELECT id FROM product.attribute WHERE channel_id = 3 AND name = 'Shoes'),(SELECT id FROM product.navigation_tree WHERE attribute_id = (SELECT id FROM product.attribute WHERE channel_id = 3 AND name = 'Shop' AND attribute_type_id = 0)),2,true,false,null,'');
INSERT INTO product.navigation_tree VALUES (default,(SELECT id FROM product.attribute WHERE channel_id = 3 AND name = 'Unknown'),(SELECT id FROM product.navigation_tree WHERE attribute_id = (SELECT id FROM product.attribute WHERE channel_id = 3 AND name = 'Shop' AND attribute_type_id = 0)),3,false,false,null,'');

COMMIT WORK;
