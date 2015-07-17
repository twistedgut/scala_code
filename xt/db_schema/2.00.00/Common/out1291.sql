--
-- Additional columns and data required for OUT-1291
--
BEGIN;
    ALTER TABLE event.detail
        ADD COLUMN  description     text,
        ADD COLUMN  dont_miss_out   varchar(255),
        ADD COLUMN  sponsor_id      integer
    ;

    INSERT INTO event.website
    (id, name)
    VALUES
    (3, 'OUT-Intl'),
    (4, 'OUT-AM')
    ;
COMMIT;
