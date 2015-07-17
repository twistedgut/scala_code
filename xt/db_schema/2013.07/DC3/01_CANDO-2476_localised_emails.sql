-- CANDO-2476: Update the default Email Addreses used in the 'localised_email_address' table

BEGIN WORK;

UPDATE  localised_email_address
    SET email_address = CASE
        WHEN email_address = 'customercare.cn@net-a-porter.com'
            THEN 'customercare.apac@net-a-porter.com'
        WHEN email_address = 'fashionadvisors.cn@net-a-porter.com'
            THEN 'fashionadvisors.apac@net-a-porter.com'
        ELSE email_address
END;

COMMIT WORK;
