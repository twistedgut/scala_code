BEGIN;

UPDATE country_tax_code
    SET code='NL 8238.10.380.B01'
    WHERE country_id = (select id from country where country= 'Netherlands')
      AND channel_id = (select id from channel where name='JIMMYCHOO.COM');

COMMIT;
