-- Purpose: Active flag to determine which seasons products are selling on the site
--  

BEGIN;

alter table season add column active boolean not null default false;

update season set active = true where season_year > 2006;


COMMIT;