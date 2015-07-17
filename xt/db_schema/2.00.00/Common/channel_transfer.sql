BEGIN;

-- create new PWS and stock actions for a channel transfer
insert into stock_action values (14, 'Channel Transfer Out');
insert into stock_action values (15, 'Channel Transfer In');

insert into pws_action values (14, 'Channel Transfer Out');
insert into pws_action values (15, 'Channel Transfer In');


COMMIT;