-- new schema for website designer navigation management

BEGIN;

alter table designer add column url_key varchar(255) not null default '';


COMMIT;

