BEGIN;

alter table pack_lane add column tote_count integer NOT NULL default 0;

alter table pack_lane add column is_sample boolean NOT NULL default 'f';
alter table pack_lane add column is_premier boolean NOT NULL default 'f';

update pack_lane set is_sample = 't' where human_name = 'seasonal_line';
update pack_lane set is_premier = 't' where human_name in ('pack_lane_1', 'multi_tote_pack_lane_1');

alter table pack_lane alter column is_sample drop default;
alter table pack_lane alter column is_premier drop default;

drop table pack_lane_has_attribute;
drop table pack_lane_attribute;

COMMIT;
