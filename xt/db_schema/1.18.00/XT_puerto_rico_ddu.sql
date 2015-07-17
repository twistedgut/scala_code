
-- switch Puerto Rico to be DDU

update country set shipment_type_id = 5 where country = 'Puerto Rico';

delete from country_duty_rate where country_id = (select id from country where country = 'Puerto Rico');