
begin;
create table public.variant_measurement_backup (variant_id integer not null, measurement_id integer not null, value varchar(255));
alter table public.variant_measurement_backup owner to postgres;
insert into public.variant_measurement_backup select * from public.variant_measurement;
update public.variant_measurement set value=trim(value) where value like '% %';
delete from public.variant_measurement where value not similar to E'\[0-9]*\.?\[0-9\]*' or length(value) = 0 or length(value) > 8 or value='.' or value='0' or value is null;
alter table public.variant_measurement add column value2 numeric;
update public.variant_measurement set value2=cast(value as numeric);
alter table public.variant_measurement alter column value2 set not null;
alter table public.variant_measurement drop column value;
alter table public.variant_measurement rename column value2 to value;
commit;
