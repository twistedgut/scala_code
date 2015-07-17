--
-- DCA-955 - avoid "uninitialized value in hash element at lib/XTracker/Navigation.pm line 146."

BEGIN;

update authorisation_sub_section set ord=1 where ord is null;
alter table authorisation_sub_section alter column ord set not null;
alter table authorisation_sub_section alter column ord set default 1;

COMMIT;
