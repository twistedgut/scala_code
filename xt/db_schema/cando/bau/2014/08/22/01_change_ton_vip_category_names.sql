BEGIN;

UPDATE customer_category
    SET category = 'Vip Black'
        WHERE category = 'Black Vip';

UPDATE customer_category
    SET category = 'Vip Gold'
        WHERE category = 'Gold Vip';

UPDATE customer_category
    SET category = 'Vip Silver'
        WHERE category = 'Silver Vip';

UPDATE customer_category
    SET category = 'Vip Bronze'
        WHERE category = 'Bronze Vip';

COMMIT;
