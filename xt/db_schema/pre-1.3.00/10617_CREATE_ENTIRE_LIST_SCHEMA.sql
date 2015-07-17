--
-- THIS SCRIPT NEEDS TO BE RUN FROM THE DIRECTORY ABOVE db_schema/
--
-- $ psql --quiet -d xtracker -f db_schema/10617_CREATE_ENTIRE_LIST_SCHEMA.sql
--

-- these are the drops to clear out any existing schema (from development)
BEGIN;
    DROP schema IF EXISTS list CASCADE;
    DROP schema IF EXISTS editorial CASCADE;
    DROP schema IF EXISTS photography CASCADE;
    DROP schema IF EXISTS upload CASCADE;
    DROP schema IF EXISTS product CASCADE;
    DROP schema IF EXISTS display CASCADE;
COMMIT; -- change this to a commit if you really want to drop them

-- make sure we have out default index trigger
\i db_schema/9938_default_index_trigger.sql

-- fix the authorisation table!
\i db_schema/10617_authorisation_fix.sql
-- add view to simply the previously complex product summary for displaying
\i db_schema/10617_product_summary_view.sql
-- these are the new permissions for the worklist screens
\i db_schema/10617_photography_worklist_permissions.sql
\i db_schema/10617_editorial_worklist_permissions.sql
\i db_schema/10617_upload_worklist_permissions.sql
\i db_schema/10617_fitnotes_worklist_permissions.sql

-- the new schemas and tables, etc
\i db_schema/10617_display_new_schema.sql
\i db_schema/10617_last_modified_fix.sql
\i db_schema/10617_list_new_schema.sql
\i db_schema/10617_product_new_schema.sql
\i db_schema/10617_photography_new_schema.sql
\i db_schema/10617_editorial_new_schema.sql
\i db_schema/10617_upload_new_schema.sql
\i db_schema/10617_stock_summary.sql
\i db_schema/10617_upload_date_view.sql
\i db_schema/create_prod_attributes_patch.sql
