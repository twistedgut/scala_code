-- Purpose:
--  Create new tables for Perpetual Inventory Reports section

BEGIN;


-- Create summary table for stock counting
create table stock_count_category_summary (
	id serial primary key, 
	start_date timestamp NOT NULL,
	end_date timestamp NOT NULL,
	stock_count_category_id integer references stock_count_category(id) NOT NULL,
	pre_counts_required integer NOT NULL,
	post_counts_required integer NOT NULL,
	counts_completed integer NOT NULL
	);

grant all on stock_count_category_summary to www;
grant all on stock_count_category_summary_id_seq to www;


-- Do it!
COMMIT;
