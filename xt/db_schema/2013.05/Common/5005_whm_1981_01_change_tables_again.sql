BEGIN;

alter table container alter column has_arrived drop default;

-- allow has_arrived to be null so index is quicker when searching table for has_arrived=false.
update container set has_arrived=null where pack_lane_id is null;
create index idx_container_has_arrived_pack_lane on container(has_arrived, pack_lane_id);

-- rename tote_count to container_count
alter table pack_lane rename tote_count to container_count;

-- readd the relationship stuff
create table pack_lane_attribute (
   pack_lane_attribute_id integer primary key,
   name varchar(255) not null unique
);

alter table public.pack_lane_attribute owner to www;

insert into pack_lane_attribute (pack_lane_attribute_id, name) values
    (1, 'STANDARD'),
    (2, 'PREMIER'),
    (3, 'SAMPLE'),
    (4, 'DEFAULT'),
    (5, 'SINGLE'),
    (6, 'MULTITOTE')
;

create table pack_lane_has_attribute (
    pack_lane_id integer not null references pack_lane(pack_lane_id),
    pack_lane_attribute_id integer not null references pack_lane_attribute(pack_lane_attribute_id),
    primary key(pack_lane_id, pack_lane_attribute_id)
);

alter table public.pack_lane_has_attribute owner to www;

-- populate standard lanes with standard flag
insert into pack_lane_has_attribute
select p.pack_lane_id, pla.pack_lane_attribute_id
from pack_lane p, pack_lane_attribute pla
where pla.name = 'STANDARD' and p.is_premier = 'f';

-- populate premier lanes with premier flag
insert into pack_lane_has_attribute
select p.pack_lane_id, pla.pack_lane_attribute_id
from pack_lane p, pack_lane_attribute pla
where pla.name = 'PREMIER' and p.is_premier = 't';

-- populate sample lane with samples flag
insert into pack_lane_has_attribute
select p.pack_lane_id, pla.pack_lane_attribute_id
from pack_lane p, pack_lane_attribute pla
where pla.name = 'SAMPLE' and p.is_sample = 't';

-- attach the DEFAULT value to the no_read lane
insert into pack_lane_has_attribute
select p.pack_lane_id, pla.pack_lane_attribute_id
from pack_lane p, pack_lane_attribute pla
where pla.name = 'DEFAULT' and p.human_name='packing_no_read';

-- attach single tote attribute to single tote lanes
insert into pack_lane_has_attribute
select p.pack_lane_id, pla.pack_lane_attribute_id
from pack_lane p, pack_lane_attribute pla
where pla.name = 'SINGLE' and (
   p.human_name like 'pack_lane_%'
or p.human_name='packing_no_read'
or p.human_name='seasonal_line');

-- attach multitote attribute to multitote lanes
insert into pack_lane_has_attribute
select p.pack_lane_id, pla.pack_lane_attribute_id
from pack_lane p, pack_lane_attribute pla
where pla.name = 'MULTITOTE' and (
   p.human_name like 'multi_tote_pack_lane_%'
or p.human_name='packing_no_read'
or p.human_name='seasonal_line');

-- drop old data structures
alter table pack_lane drop column type;
drop table pack_lane_type;

alter table pack_lane drop column is_sample;
alter table pack_lane drop column is_premier;

ALTER TABLE pack_lane ADD COLUMN is_editable BOOLEAN NOT NULL DEFAULT TRUE;
UPDATE pack_lane SET is_editable = FALSE WHERE human_name='packing_no_read';
UPDATE pack_lane SET active = FALSE WHERE human_name!='packing_no_read';

COMMIT;
