-- Purpose: Create Lyris table to store customer and coupon code
--  

BEGIN;

create table customer_promotion (
	promotion_number varchar(255) not null,
	customer_id integer not null,
	coupon_code varchar(255) null,
	unique(promotion_number, customer_id)
	);

COMMIT;