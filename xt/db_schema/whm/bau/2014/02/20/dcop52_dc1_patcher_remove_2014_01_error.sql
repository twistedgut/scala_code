BEGIN;

update dbadmin.applied_patch set succeeded = true where filename='DC1/30-whm_2901_jc_box_update.sql';

COMMIT;
