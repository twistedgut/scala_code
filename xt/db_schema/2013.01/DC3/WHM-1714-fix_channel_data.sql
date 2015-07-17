BEGIN;

    UPDATE channel SET company_registration_number = '1625923';
    UPDATE channel SET company_registration_number = '07611298' where name='JIMMYCHOO.COM';
    
    UPDATE channel SET colour_detail_override = true where name='theOutnet.com';

COMMIT;
