USE seaview;

START TRANSACTION;

UPDATE accountCategory
    SET name = 'Vip Black', guid = 'vip_black'
        WHERE name = 'Black Vip';


UPDATE accountCategory
    SET name = 'Vip Gold', guid = 'vip_gold'
        WHERE name = 'Gold Vip';

UPDATE accountCategory
    SET name = 'Vip Silver', guid = 'vip_silver'
        WHERE name = 'Silver Vip';

UPDATE accountCategory
    SET name = 'Vip Bronze', guid = 'vip_bronze'
        WHERE name = 'Bronze Vip';

COMMIT;
