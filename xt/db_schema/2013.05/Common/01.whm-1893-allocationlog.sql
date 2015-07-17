BEGIN;

create table allocation_item_log (
    id SERIAL PRIMARY KEY,
    date timestamp with time zone NOT NULL default now(),
    operator_id integer references operator(id) not null,
    allocation_status_id integer references allocation_status(id) not null, -- status for the entire allocation
    allocation_item_id integer references allocation_item(id) not null,
    allocation_item_status_id integer references allocation_item_status(id) not null  -- status for the individual allocation item
);

alter table allocation_item_log owner to www;

COMMIT;
