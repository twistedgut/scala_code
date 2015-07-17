-- see http://animal/browse/XTR-658

BEGIN;

    -- new field to store response
    alter table card_payment add column threedsecure_response varchar(255) null;

    -- new order flag for finance
    insert into flag values (52, '3D Secure', 2);

COMMIT;
