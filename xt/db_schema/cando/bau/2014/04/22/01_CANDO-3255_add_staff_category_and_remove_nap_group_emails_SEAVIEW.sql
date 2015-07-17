-- CANDO-3255: Create a new Staff Category and remove the NAP Group
--             Email domains from the 'defaultCategory' table

--
-- For Seaview
--

USE seaview;

START TRANSACTION;

-- New Customer Category
INSERT INTO accountCategory (guid,name,accountClassId) VALUES (
    'staff_open_shipping',
    'Staff Open Shipping',
    (
        SELECT  id
        FROM    accountClass
        WHERE   guid = 'staff'
    )
);

-- Remove NAP Group Email Domains
DELETE FROM defaultCategory
WHERE LOWER( emailDomain ) IN (
    'net-a-porter.com',
    'mrporter.com',
    'theoutnet.com'
)
;

COMMIT;
