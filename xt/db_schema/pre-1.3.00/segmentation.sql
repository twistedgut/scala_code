-- Purpose:
--  Create tables to store data about which market segment customers fall into,
--  and log when they move between segments

--
-- Drop new tables for segments
--

BEGIN;
drop table customer_category_log;
drop table customer_segment_log;
drop table customer_segment;
drop table segment_param_spend;
drop table segment_param_time;
drop table segment;
drop table segment_type;
COMMIT;

--
-- Create new tables for segments
--

BEGIN;

create table segment_type (
        id serial primary key, 
	type varchar(255)
        );

grant all on segment_type to www;
grant all on segment_type_id_seq to www;


create table segment (
        id serial primary key, 
	segment_type_id integer references segment_type(id),
        segment varchar(255) NOT NULL
        );

grant all on segment to www;
grant all on segment_id_seq to www;

CREATE TABLE customer_segment (
        id serial primary key, 
        customer_id integer references customer(id) NOT NULL,

        -- In an ideal world, the following CHECK() constraint would refer to 
        -- segment.segment_type_id, but you can't use subqueries inside a CHECK()
	spending_segment_id integer references segment(id) 
		CHECK((spending_segment_id >= 1 AND spending_segment_id <= 4) OR spending_segment_id IS NULL ),
	-- First shopped in last 12 months, spent >£1000 on 1st order
	potential_order1_segment_id integer references segment(id)
		CHECK((potential_order1_segment_id = 10 OR potential_order1_segment_id IS NULL)),
	-- First shopped in last 12 months, spent >£1000 in last 6 months
	potential_initial_segment_id integer references segment(id) 
		CHECK((potential_initial_segment_id = 9 OR potential_initial_segment_id IS NULL)),
	recency_segment_id integer references segment(id) NOT NULL 
		CHECK(recency_segment_id >=5 AND recency_segment_id <= 8),
	primary_segment_id integer references segment(id) NOT NULL 
        );

grant all on customer_segment to www;
grant all on customer_segment_id_seq to www;


-- Audit trails. 1 row per changed value
create table customer_segment_log (
        id serial primary key, 
        customer_id integer references customer(id) NOT NULL,
	segment_id integer references segment(id),
	segment_type_id integer references segment_type(id) NOT NULL,
        date date NOT NULL
        );

grant all on customer_segment_log to www;
grant all on customer_segment_log_id_seq to www;

create table customer_category_log (
        id serial primary key, 
        customer_id integer references customer(id) NOT NULL,
	customer_category_id integer references customer_category(id) NOT NULL,
        date date NOT NULL
        );

grant all on customer_category_log to www;
grant all on customer_category_log_id_seq to www;

--
-- Data for segments
--

INSERT INTO segment_type (id, type) VALUES (1, 'spending');
INSERT INTO segment_type (id, type) VALUES (2, 'recency');
INSERT INTO segment_type (id, type) VALUES (3, 'potential_inital');
INSERT INTO segment_type (id, type) VALUES (4, 'potential_order1');
INSERT INTO segment_type (id, type) VALUES (5, 'extended');
INSERT INTO segment_type (id, type) VALUES (6, 'primary');

-- (Spend > £5,000) in last 18 months
INSERT INTO segment (segment_type_id, segment) VALUES (1, 'Top Spender');       --1
-- (£5,000 >= Spend < £2,500) in last 18 months
INSERT INTO segment (segment_type_id, segment) VALUES (1, 'High Spender');      --2
-- (£500 >= Spend < £2,500) in last 18 months
INSERT INTO segment (segment_type_id, segment) VALUES (1, 'Medium Spender');    --3
-- (Spend < £500) in last 18 months AND first shopped more than 12 months ago
INSERT INTO segment (segment_type_id, segment) VALUES (1, 'Low Spender');       --4

-- First shopped in last 12 months AND total spend < £2,500
INSERT INTO segment (segment_type_id, segment) VALUES (2, 'New Customer');      --5
-- Last shopped less than 18 months ago 
INSERT INTO segment (segment_type_id, segment) VALUES (2, 'Active Customer');   --6
-- Last shopped less than 36 months ago, more than 18 months ago
INSERT INTO segment (segment_type_id, segment) VALUES (2, 'Lapsed Customer');   --7
-- Last shopped more than 36 months ago
INSERT INTO segment (segment_type_id, segment) VALUES (2, 'Inactive Customer'); --8

INSERT INTO segment (segment_type_id, segment) VALUES (3, 'Potential High Spender - Initial Period'); --9
INSERT INTO segment (segment_type_id, segment) VALUES (4, 'Potential High Spender - First Order');    --10

-- Used when customer_category is not RCustomer
INSERT INTO segment (segment_type_id, segment) VALUES (5, 'Customer Category');    --11

---
--- Segmentation parameters tables
---

create table segment_param_time (
	id serial primary key,
	segment_id integer references segment(id),
	lower_bound_months integer,
	upper_bound_months integer
	);

grant all on segment_param_time to www;
grant all on segment_param_time_id_seq to www;

create table segment_param_spend (
	id serial primary key,
	segment_id integer references segment(id),
	lower_bound_amount integer,
	upper_bound_amount integer
	);

grant all on segment_param_spend to www;
grant all on segment_param_spend_id_seq to www;

---
--- Segmentation parameters data
---

-- Amount customers must spend over defined period to fall into each segment
-- Top Spender
INSERT INTO segment_param_spend (segment_id, lower_bound_amount, upper_bound_amount) VALUES (1,  5000, NULL);
-- High Spender
INSERT INTO segment_param_spend (segment_id, lower_bound_amount, upper_bound_amount) VALUES (2,  2500, 5000);
-- Medium Spender
INSERT INTO segment_param_spend (segment_id, lower_bound_amount, upper_bound_amount) VALUES (3,  500,  2500);
-- Low Spender
INSERT INTO segment_param_spend (segment_id, lower_bound_amount, upper_bound_amount) VALUES (4,  0,    500);
-- Potential High Spender, Initial Period
INSERT INTO segment_param_spend (segment_id, lower_bound_amount, upper_bound_amount) VALUES (9,  1000, NULL);
-- Potential High Spender, 1st order
INSERT INTO segment_param_spend (segment_id, lower_bound_amount, upper_bound_amount) VALUES (10, 1000, NULL);

-- Periods over which to consider spending history (18 months)
INSERT INTO segment_param_time (segment_id, lower_bound_months, upper_bound_months) VALUES (1, 0, 18);
INSERT INTO segment_param_time (segment_id, lower_bound_months, upper_bound_months) VALUES (2, 0, 18);
INSERT INTO segment_param_time (segment_id, lower_bound_months, upper_bound_months) VALUES (3, 0, 18);
INSERT INTO segment_param_time (segment_id, lower_bound_months, upper_bound_months) VALUES (4, 0, 18);
-- Potential High Spender, Initial Period: This sets how long the Initial Period actually is (6 months)
INSERT INTO segment_param_time (segment_id, lower_bound_months, upper_bound_months) VALUES (9, 0, 6);


-- Time since first order to consider someone a new customer (12 months)
INSERT INTO segment_param_time (segment_id, lower_bound_months, upper_bound_months) VALUES (5, 0, 12);

-- Time since last order to consider someone an active customer (18 months or less)
INSERT INTO segment_param_time (segment_id, lower_bound_months, upper_bound_months) VALUES (6, 0, 18);
-- Time since last order to consider someone a lapsed customer (18-36 months)
INSERT INTO segment_param_time (segment_id, lower_bound_months, upper_bound_months) VALUES (7, 18, 36);
-- Time since last order to consider someone an inactive customer (36 months or greater)
INSERT INTO segment_param_time (segment_id, lower_bound_months, upper_bound_months) VALUES (8, 36, NULL);

--
-- SELECTs to verify that things look about right
--

SELECT s.id, s.segment, st.type, sps.lower_bound_amount, sps.upper_bound_amount 
FROM segment_param_spend sps, segment s, segment_type st
WHERE s.id = sps.segment_id AND s.segment_type_id = st.id;

SELECT s.id, s.segment, st.type, spt.lower_bound_months, spt.upper_bound_months 
FROM segment_param_time spt, segment s, segment_type st
WHERE s.id = spt.segment_id AND s.segment_type_id = st.id;

-- Should like something like:
--  id |                 segment                 |       type       | lower_bound_amount | upper_bound_amount 
-- ----+-----------------------------------------+------------------+--------------------+--------------------
--   1 | Top Spender                             | spending         |               5000 |                   
--   2 | High Spender                            | spending         |               2500 |               5000
--   3 | Medium Spender                          | spending         |                500 |               2500
--   4 | Low Spender                             | spending         |                  0 |                500
--   9 | Potential High Spender - Initial Period | potential_inital |               1000 |                  
--  10 | Potential High Spender - First Order    | potential_order1 |               1000 |                  
-- (6 rows)

--  id |                 segment                 |       type       | lower_bound_months | upper_bound_months 
-- ----+-----------------------------------------+------------------+--------------------+--------------------
--   1 | Top Spender                             | spending         |                  0 |                 18
--   2 | High Spender                            | spending         |                  0 |                 18
--   3 | Medium Spender                          | spending         |                  0 |                 18
--   4 | Low Spender                             | spending         |                  0 |                 18
--   9 | Potential High Spender - Initial Period | potential_inital |                  0 |                  6
--   5 | New Customer                            | recency          |                  0 |                 12
--   6 | Active Customer                         | recency          |                  0 |                 18
--   7 | Lapsed Customer                         | recency          |                 18 |                 36
--   8 | Inactive Customer                       | recency          |                 36 |                   
-- (9 rows)

COMMIT;

BEGIN;
-- The following is wrapped in a seperate begin/commit block because it will fail if run twice on the same db

--
-- PR need some new categories which don't currently exist in XT
--

-- TODO: Find out if these should have a discount value
INSERT INTO customer_category (category, discount) VALUES ('20% Discount', 0.000);
INSERT INTO customer_category (category, discount) VALUES ('30% Discount', 0.000);
INSERT INTO customer_category (category, discount) VALUES ('EIP Premium',  0.000);
INSERT INTO customer_category (category, discount) VALUES ('EIP Honorary', 0.000);
INSERT INTO customer_category (category, discount) VALUES ('IP',           0.000);

COMMIT;