-- Remove session_id from dbl_submit_token

BEGIN work;

    ALTER TABLE public.dbl_submit_token
        DROP COLUMN session_id;

COMMIT;
