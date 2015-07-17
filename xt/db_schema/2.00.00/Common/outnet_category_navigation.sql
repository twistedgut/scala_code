

BEGIN;

-- populate attribute table
INSERT INTO product.attribute (id, name, attribute_type_id, channel_id) VALUES(default, 'Shop', 0, (SELECT id FROM channel WHERE name = 'The Outnet'));

INSERT INTO product.attribute (name, attribute_type_id, deleted, channel_id) (
SELECT a.name, a.attribute_type_id, a.deleted, (SELECT id FROM channel WHERE name = 'The Outnet') FROM product.attribute a, product.navigation_tree nt WHERE a.attribute_type_id = 1 AND a.channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER') AND a.id = nt.attribute_id AND nt.parent_id = 1
ORDER BY nt.sort_order ASC
);

INSERT INTO product.attribute (name, attribute_type_id, deleted, channel_id) (
SELECT name, attribute_type_id, deleted, (SELECT id FROM channel WHERE name = 'The Outnet') FROM product.attribute WHERE attribute_type_id = 2 AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER') 
);

INSERT INTO product.attribute (name, attribute_type_id, deleted, channel_id) (
SELECT name, attribute_type_id, deleted, (SELECT id FROM channel WHERE name = 'The Outnet') FROM product.attribute WHERE attribute_type_id = 3 AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER') 
);


-- populate table
INSERT INTO product.attribute_value (product_id, attribute_id) (SELECT pc.product_id, cat.id FROM product_channel pc, product p, classification c, product.attribute cat where pc.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet') AND pc.product_id = p.id AND p.classification_id = c.id and replace(c.classification, ' ', '_') = cat.name and cat.attribute_type_id = 1 AND cat.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet'));

INSERT INTO product.attribute_value (product_id, attribute_id) (SELECT pc.product_id, cat.id FROM product_channel pc, product p, product_type pt, product.attribute cat where pc.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet') AND pc.product_id = p.id AND p.product_type_id = pt.id and replace(pt.product_type, ' ', '_') = cat.name and cat.attribute_type_id = 2 AND cat.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet'));

INSERT INTO product.attribute_value (product_id, attribute_id) (SELECT pc.product_id, cat.id FROM product_channel pc, product p, sub_type st, product.attribute cat where pc.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet') AND pc.product_id = p.id AND p.sub_type_id = st.id and replace(st.sub_type, ' ', '_') = cat.name and cat.attribute_type_id = 3 AND cat.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet'));

INSERT INTO product.attribute_value (product_id, attribute_id) (SELECT p.product_id, cat.id FROM product_channel p, product.attribute cat where cat.name = 'Unknown' and cat.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet') and cat.attribute_type_id = 2 and p.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet') and p.product_id not in (select product_id from product.attribute_value where deleted = false and attribute_id in (select id from product.attribute where attribute_type_id = 2 and channel_id = (SELECT id FROM channel WHERE name = 'The Outnet'))));

INSERT INTO product.attribute_value (product_id, attribute_id) (SELECT p.product_id, cat.id FROM product_channel p, product.attribute cat where cat.name = 'Unknown' and cat.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet') and cat.attribute_type_id = 3 and p.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet') and p.product_id not in (select product_id from product.attribute_value where deleted = false and attribute_id in (select id from product.attribute where attribute_type_id = 3 and channel_id = (SELECT id FROM channel WHERE name = 'The Outnet'))));


-- clone NAP tree to populate OUTNET category tree

INSERT INTO product.navigation_tree (attribute_id, parent_id, sort_order, visible) VALUES ((SELECT id FROM product.attribute WHERE name = 'Shop' AND channel_id = (SELECT id FROM channel WHERE name = 'The Outnet')), null, 1, false);

-- roots
INSERT INTO product.navigation_tree (attribute_id, parent_id, sort_order, visible, deleted) (SELECT att.id, (SELECT id FROM product.navigation_tree WHERE attribute_id = (SELECT id FROM product.attribute WHERE name = 'Shop' AND channel_id = (SELECT id FROM channel WHERE name = 'The Outnet') ) ), nt.sort_order, nt.visible, nt.deleted FROM product.attribute att, product.attribute nap, product.navigation_tree nt WHERE nap.channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER') AND nap.attribute_type_id = 1 AND nap.id = nt.attribute_id AND nt.parent_id IN (SELECT id FROM product.navigation_tree WHERE attribute_id IN (SELECT id FROM product.attribute WHERE name = 'Shop')) AND nap.name = att.name AND att.attribute_type_id = 1 AND att.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet'));

--branches
INSERT INTO product.navigation_tree (attribute_id, parent_id, sort_order, visible, deleted) 
(SELECT out_att.id, out_parent_tree.id, nap_tree.sort_order, nap_tree.visible, nap_tree.deleted 
  FROM product.attribute out_att, product.attribute nap_att, product.navigation_tree nap_tree, product.navigation_tree nap_parent_tree, product.attribute nap_parent_att, product.navigation_tree out_parent_tree, product.attribute out_parent_att 
  WHERE nap_att.channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER') 
  AND nap_att.attribute_type_id = 2 
  AND nap_att.id = nap_tree.attribute_id 
  AND nap_att.name = out_att.name 
  AND out_att.attribute_type_id = 2 
  AND out_att.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet')
  AND nap_tree.parent_id = nap_parent_tree.id
  AND nap_parent_tree.attribute_id = nap_parent_att.id
  AND nap_parent_att.attribute_type_id = 1
  AND nap_parent_att.channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER') 
  AND nap_parent_att.name = out_parent_att.name
  AND out_parent_att.attribute_type_id = 1 
  AND out_parent_att.channel_id = (SELECT id FROM channel WHERE name = 'The Outnet')
  AND out_parent_att.id = out_parent_tree.attribute_id
);

COMMIT;
