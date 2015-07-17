--
-- update the pre-order email templates to use the new pre-order field name
--

BEGIN WORK;

UPDATE correspondence_templates
   SET content = REPLACE( content,
                          'product.product_attribute.name',
                          'product.preorder_name' )
 WHERE NAME LIKE 'Pre Order%'
     ;

COMMIT WORK;
