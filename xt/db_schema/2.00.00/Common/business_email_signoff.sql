BEGIN;

ALTER TABLE business ADD column email_signoff varchar(100);

UPDATE business SET email_signoff = 'Customer Care' WHERE name = 'NET-A-PORTER';
UPDATE business SET email_signoff = 'Service Team' WHERE name = 'The Outnet';


COMMIT;