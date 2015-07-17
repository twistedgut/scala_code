-- CANDO-8632: Create Back-Fill jobs to Back-Fill the new 'last_updated'
--             fields on the 'return' and 'return_item' tables

BEGIN WORK;

INSERT INTO dbadmin.back_fill_job (
        name,
        description,
        back_fill_job_status_id,
        back_fill_table_name,
        back_fill_primary_key_field,
        update_set,
        resultset_from,
        resultset_where,
        resultset_order_by,
        max_rows_to_update,
        max_jobs_to_create,
        time_to_start_back_fill,
        contact_email_address
    ) VALUES
--
-- 'return' table
--
(
    'CANDO-8632: Update ''last_updated'' on ''return'' Table',      -- name
    'CANDO-8632: Update ''last_updated'' on ''return'' Table',      -- description
    ( SELECT id FROM dbadmin.back_fill_job_status WHERE status = 'New' ),
    'return',                                                       -- back_fill_table_name
    'id',                                                           -- back_fill_primary_key_field
    'last_updated = ''2015-05-12 00:00:00''',                       -- update_set - when the columns were added
    'return',                                                       -- resultset_from
    'last_updated IS NULL',                                         -- resultset_where
    'id',                                                           -- resultset_order_by
    1000,                                                           -- max_rows_to_update - 1000 at a time
    10,                                                             -- max_jobs_to_create - create 10 JQ Jobs at a time
    now() + INTERVAL '1 HOUR',                                      -- time_to_start_back_fill, start one hour after to release
    'cando-dev@net-a-porter.com'                                    -- contact_email_address
),
--
-- 'return_item' table
--
(
    'CANDO-8632: Update ''last_updated'' on ''return_item'' Table', -- name
    'CANDO-8632: Update ''last_updated'' on ''return_item'' Table', -- description
    ( SELECT id FROM dbadmin.back_fill_job_status WHERE status = 'New' ),
    'return_item',                                                  -- back_fill_table_name
    'id',                                                           -- back_fill_primary_key_field
    'last_updated = ''2015-05-12 00:00:00''',                       -- update_set - when the columns were added
    'return_item',                                                  -- resultset_from
    'last_updated IS NULL',                                         -- resultset_where
    'id',                                                           -- resultset_order_by
    1000,                                                           -- max_rows_to_update - 1000 at a time
    10,                                                             -- max_jobs_to_create - create 10 JQ Jobs at a time
    now() + INTERVAL '1 HOUR',                                      -- time_to_start_back_fill, start one hour after to release
    'cando-dev@net-a-porter.com'                                    -- contact_email_address
)
;

COMMIT WORK;

