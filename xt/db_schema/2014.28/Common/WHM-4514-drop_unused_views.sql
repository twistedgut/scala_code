-- Drop legacy unused views

BEGIN;
    DROP VIEW vw_sample_request_dets, vw_sample_request_det_current_status;
COMMIT;
