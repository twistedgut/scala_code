-- Previous product.navigation_tree for mrp wasn't quite right,
-- this should sort it out,
-- (See db_schema/2010.25/DC1/01-channels-mrporter-designer-product-attribute.sql
-- for previous patch).

BEGIN;

update product.navigation_tree set attribute_id=(
 select id from product.attribute where channel_id=5 and name='Shoes' and attribute_type_id=1
) 
 where attribute_id=(
 select id from product.attribute where channel_id=1 and name='Shoes' and attribute_type_id=1
) 
 and parent_id in (
  select id from product.navigation_tree where attribute_id in (
   select id from product.attribute where channel_id=5 and
    (attribute_type_id=9 or (attribute_type_id=0 and name='Shop')) 
  )
 )
;


update product.navigation_tree set attribute_id=(
 select id from product.attribute where channel_id=5 and name='Accessories' and attribute_type_id=1
) 
 where attribute_id=(
 select id from product.attribute where channel_id=1 and name='Accessories' and attribute_type_id=1
) 
 and parent_id in (
  select id from product.navigation_tree where attribute_id in (
   select id from product.attribute where channel_id=5 and
    (attribute_type_id=9 or (attribute_type_id=0 and name='Shop')) 
  )
 )
;


update product.navigation_tree set attribute_id=(
 select id from product.attribute where channel_id=5 and name='Clothing' and attribute_type_id=1
) 
 where attribute_id=(
 select id from product.attribute where channel_id=1 and name='Clothing' and attribute_type_id=1
) 
 and parent_id in (
  select id from product.navigation_tree where attribute_id in (
   select id from product.attribute where channel_id=5 and
    (attribute_type_id=9 or (attribute_type_id=0 and name='Shop')) 
  )
 )
;


update product.navigation_tree set attribute_id=(
 select id from product.attribute where channel_id=5 and name='Bags' and attribute_type_id=1
) 
 where attribute_id=(
 select id from product.attribute where channel_id=1 and name='Bags' and attribute_type_id=1
) 
 and parent_id in (
  select id from product.navigation_tree where attribute_id in (
   select id from product.attribute where channel_id=5 and
    (attribute_type_id=9 or (attribute_type_id=0 and name='Shop')) 
  )
 )
;

COMMIT;
