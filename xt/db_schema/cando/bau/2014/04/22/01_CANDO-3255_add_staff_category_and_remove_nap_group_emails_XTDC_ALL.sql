-- CANDO-3255: Create a new Staff Category and remove the NAP Group
--             Email domains from the 'customer_category_defaults' table

--
-- For ALL xTracker DCs
--

BEGIN WORK;

-- New Customer Category
INSERT INTO customer_category (category, fast_track, customer_class_id) VALUES (
    'Staff Open Shipping',
    TRUE,
    (
        SELECT  id
        FROM    customer_class
        WHERE   class = 'Staff'
    )
);

-- Remove NAP Group Email Domains
DELETE FROM customer_category_defaults
WHERE TRIM( LOWER( email_domain ) ) IN (
    'net-a-porter.com',
    'mrporter.com',
    'theoutnet.com'
)
;

COMMIT WORK;
