BEGIN;

insert into log_pws_stock (variant_id, pws_action_id, operator_id, notes, quantity, balance, date, channel_id)
values (4311906, 11, 1, 'added for DCOP-576', 1, 1, '2014-05-15 00:00:00', 1);

COMMIT;
