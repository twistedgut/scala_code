-- NOTE: This patch is duplicated in the DC1/DC2/DC3 directories instead of being
-- under Common, because for the DC2 database it needs to run after the
-- DC2/15-dca-3254-populate-prl-table.sql patch.

BEGIN;

alter table allocation add column prl_id integer references prl(id) deferrable;

update allocation set prl_id = (select id from prl where name = prl);

alter table allocation alter column prl_id set not null;

alter table allocation drop column prl;

COMMIT;
