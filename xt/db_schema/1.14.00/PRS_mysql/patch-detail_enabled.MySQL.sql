START TRANSACTION;
    ALTER TABLE detail
        ADD COLUMN enabled
             boolean     null default null
    ;
COMMIT;
