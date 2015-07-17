BEGIN;

update flag set description = 'Finance Watch' where description = 'Fin Watch';
update flag set description = 'Address' where description = 'Addr';

update flag set description = 'Weekly Order Value Limit' where description = 'Over 2000 Value in a Week';
update flag set description = 'Weekly Order Count Limit' where description = '5 Orders in a Week';
update flag set description = 'Daily Order Count Limit' where description = '3 orders in a day';
update flag set description = 'Total Order Value Limit' where description = 'Spent over 5000';

COMMIT;