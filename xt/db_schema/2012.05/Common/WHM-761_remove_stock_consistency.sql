-- Remove all traces of stock consistency tables

BEGIN;
    DELETE FROM operator_authorisation WHERE authorisation_sub_section_id =
        ( SELECT id FROM authorisation_sub_section WHERE sub_section = 'Stock Consistency' );
    DELETE FROM authorisation_sub_section where sub_section = 'Stock Consistency';
COMMIT;
