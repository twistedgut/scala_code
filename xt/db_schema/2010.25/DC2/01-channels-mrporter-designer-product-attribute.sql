-- Create product.attribute values for designer type for MrP.
-- Only do it for ones that don't already have something there 
-- for that designer on the MrP channel.
-- Then make corresponding product.navigation_tree entries. This bit
-- is horrible and may well go wrong if some data already exists for 
-- MrP, but as far as I can tell it shouldn't.

BEGIN;

INSERT INTO product.attribute
    (name, attribute_type_id, deleted, synonyms, manual_sort, page_id, channel_id) 
SELECT name, attribute_type_id, deleted, synonyms, manual_sort, page_id, 6
FROM product.attribute
WHERE attribute_type_id=9 AND channel_id=2 and name not in
    (SELECT name FROM product.attribute WHERE channel_id=6 and attribute_type_id=9);


INSERT INTO product.navigation_tree
    (attribute_id, parent_id, sort_order, visible, deleted, feature_product_id, feature_product_image)
SELECT pa_mrp.id, null,
    pnt_nap.sort_order, pnt_nap.visible, pnt_nap.deleted,
    pnt_nap.feature_product_id, pnt_nap.feature_product_image
FROM product.navigation_tree pnt_nap, product.attribute pa_nap, product.attribute pa_mrp
WHERE pnt_nap.attribute_id=pa_nap.id
    AND pa_nap.channel_id=2 AND pa_mrp.channel_id=6
    AND pa_nap.attribute_type_id=9 and pa_mrp.attribute_type_id=9 
    AND pa_nap.name=pa_mrp.name
;

UPDATE product.navigation_tree
SET parent_id = id
WHERE attribute_id IN
    (SELECT id FROM product.attribute WHERE channel_id=6 and attribute_type_id=9)
AND parent_id is null
;

INSERT INTO product.navigation_tree
    (attribute_id, parent_id, sort_order, visible, deleted, feature_product_id, feature_product_image)
SELECT 5, pnt_mrp.id, 1, pnt_nap2.visible, pnt_nap2.deleted,
    pnt_nap2.feature_product_id, pnt_nap2.feature_product_image
FROM product.navigation_tree pnt_mrp, product.navigation_tree pnt_nap, product.navigation_tree pnt_nap2,
    product.attribute pa_nap, product.attribute pa_mrp
WHERE pnt_mrp.attribute_id=pa_mrp.id
    AND pnt_nap.attribute_id=pa_nap.id
    AND pa_nap.channel_id=2 AND pa_mrp.channel_id=6
    AND pa_nap.name=pa_mrp.name
    AND pa_nap.attribute_type_id=9 and pa_mrp.attribute_type_id=9 
    AND pnt_nap2.attribute_id=5
    AND pnt_nap2.parent_id=pnt_nap.id
;

INSERT INTO product.navigation_tree
    (attribute_id, parent_id, sort_order, visible, deleted, feature_product_id, feature_product_image)
SELECT 6, pnt_mrp.id, 2, pnt_nap2.visible, pnt_nap2.deleted,
    pnt_nap2.feature_product_id, pnt_nap2.feature_product_image
FROM product.navigation_tree pnt_mrp, product.navigation_tree pnt_nap, product.navigation_tree pnt_nap2,
    product.attribute pa_nap, product.attribute pa_mrp
WHERE pnt_mrp.attribute_id=pa_mrp.id
    AND pnt_nap.attribute_id=pa_nap.id
    AND pa_nap.channel_id=2 AND pa_mrp.channel_id=6
    AND pa_nap.name=pa_mrp.name
    AND pa_nap.attribute_type_id=9 and pa_mrp.attribute_type_id=9 
    AND pnt_nap2.attribute_id=6
    AND pnt_nap2.parent_id=pnt_nap.id
;

INSERT INTO product.navigation_tree
    (attribute_id, parent_id, sort_order, visible, deleted, feature_product_id, feature_product_image)
SELECT 7, pnt_mrp.id, 3, pnt_nap2.visible, pnt_nap2.deleted,
    pnt_nap2.feature_product_id, pnt_nap2.feature_product_image
FROM product.navigation_tree pnt_mrp, product.navigation_tree pnt_nap, product.navigation_tree pnt_nap2,
    product.attribute pa_nap, product.attribute pa_mrp
WHERE pnt_mrp.attribute_id=pa_mrp.id
    AND pnt_nap.attribute_id=pa_nap.id
    AND pa_nap.channel_id=2 AND pa_mrp.channel_id=6
    AND pa_nap.name=pa_mrp.name
    AND pa_nap.attribute_type_id=9 and pa_mrp.attribute_type_id=9 
    AND pnt_nap2.attribute_id=7
    AND pnt_nap2.parent_id=pnt_nap.id
;

INSERT INTO product.navigation_tree
    (attribute_id, parent_id, sort_order, visible, deleted, feature_product_id, feature_product_image)
SELECT 2, pnt_mrp.id, 4, pnt_nap2.visible, pnt_nap2.deleted,
    pnt_nap2.feature_product_id, pnt_nap2.feature_product_image
FROM product.navigation_tree pnt_mrp, product.navigation_tree pnt_nap, product.navigation_tree pnt_nap2,
    product.attribute pa_nap, product.attribute pa_mrp
WHERE pnt_mrp.attribute_id=pa_mrp.id
    AND pnt_nap.attribute_id=pa_nap.id
    AND pa_nap.channel_id=2 AND pa_mrp.channel_id=6
    AND pa_nap.name=pa_mrp.name
    AND pa_nap.attribute_type_id=9 and pa_mrp.attribute_type_id=9 
    AND pnt_nap2.attribute_id=2
    AND pnt_nap2.parent_id=pnt_nap.id
;

COMMIT;
