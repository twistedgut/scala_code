BEGIN;

update inner_box
set    sort_order = sort_order + 1
where  sort_order > (
  select sort_order
  from   inner_box
  where  inner_box = 'MR P 1'
  and    channel_id = (
    select id
    from   channel
    where  name ='MRPORTER.COM'
  )
)
and channel_id = (select id from channel where name ='MRPORTER.COM');

insert into inner_box(inner_box,sort_order,active,channel_id,grouping_id)
values ('MR P 1B',
        (select (sort_order + 1) from inner_box where inner_box = 'MR P 1'),
        't',
        (select id from channel where name ='MRPORTER.COM'),
        (select grouping_id from inner_box where inner_box = 'MR P 1'));

COMMIT;
