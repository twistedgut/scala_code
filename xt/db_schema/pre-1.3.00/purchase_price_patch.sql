-- Purpose:
--  

BEGIN;

-- add new columns to the price_purchase table
alter table price_purchase add column uplift numeric(10,2) not null default 0;
alter table price_purchase add column trade_discount numeric(10,2) not null default 0;

-- back fill uplift column
update price_purchase set uplift = ((uplift_cost / original_wholesale) - 1) * 100 where original_wholesale > 0 and uplift_cost > 0;

-- back fill trade_discount column
update price_purchase set trade_discount = (1 - (wholesale_price / original_wholesale)) * 100 where original_wholesale > 0 and wholesale_price > 0;

COMMIT;