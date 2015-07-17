BEGIN;

-- rebase both conversion rate tables

delete from sales_conversion_rate ;

insert into sales_conversion_rate ( source_currency , destination_currency , conversion_rate , date_start )
	select source_currency , destination_currency , conversion_rate, '2006-01-01 00:00:00'
	from conversion_rate
	where season_id IN (select s.id from  season as s where s.season IN ( 'SS13')) ;

delete from season_conversion_rate ;

insert into season_conversion_rate (season_id , source_currency_id , destination_currency_id , conversion_rate )
	select season_id , source_currency , destination_currency , conversion_rate
	from conversion_rate
	where season_id IN ( select s.id from  season as s where s.season IN ('Continuity', 'CR13', 'SS13') ) ;

COMMIT;
