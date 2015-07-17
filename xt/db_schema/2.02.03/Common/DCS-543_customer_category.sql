BEGIN;

ALTER TABLE customer_category ADD COLUMN fast_track BOOLEAN NOT NULL DEFAULT false;

UPDATE customer_category SET fast_track = true WHERE category IN ('Promotion', 'Event', 'EIP', 'EIP Centurion', 'Staff', 'EIP Premium', 'EIP Honorary', 'IP', 'Press Contact', 'Hot Contact');

-- new categories
INSERT INTO customer_category (id, category, discount, is_visible, customer_class_id, fast_track ) VALUES (32, 'PR discount', 0, true, 5, true);
INSERT INTO customer_category (id, category, discount, is_visible, customer_class_id, fast_track ) VALUES (33, 'Board Member', 0, true, 6, true);
INSERT INTO customer_category (id, category, discount, is_visible, customer_class_id, fast_track ) VALUES (34, 'Fraud', 0, true, 1, false);
INSERT INTO customer_category (id, category, discount, is_visible, customer_class_id, fast_track ) VALUES (35, 'Critical High Returner', 0, true, 1, false);
INSERT INTO customer_category (id, category, discount, is_visible, customer_class_id, fast_track ) VALUES (36, 'No Marketing Contact', 0, true, 1, false);
INSERT INTO customer_category (id, category, discount, is_visible, customer_class_id, fast_track ) VALUES (37, 'Serious High Returner', 0, true, 1, false);

COMMIT;
 
