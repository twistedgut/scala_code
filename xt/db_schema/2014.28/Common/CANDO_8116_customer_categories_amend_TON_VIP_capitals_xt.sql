-- CANDO-8116: Amend VIP customer categories for TON to use capital letters
--
-- For all XT DCs
--

BEGIN WORK;

UPDATE customer_category
SET category = 'VIP Black'
WHERE category = 'Vip Black';

UPDATE customer_category
SET category = 'VIP Gold'
WHERE category = 'Vip Gold';

UPDATE customer_category
SET category = 'VIP Silver'
WHERE category = 'Vip Silver';

UPDATE customer_category
SET category = 'VIP Bronze'
WHERE category = 'Vip Bronze';

COMMIT WORK;
