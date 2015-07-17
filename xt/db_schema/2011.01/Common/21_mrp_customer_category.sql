BEGIN;

INSERT INTO customer_category_defaults (
category_id, email_domain
) VALUES (
(SELECT id FROM customer_category WHERE category ilike 'staff'),
'mrporter.com'
);

COMMIT;
