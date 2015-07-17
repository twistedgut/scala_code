-- Add delete cascade to rma_request_detail_status_log

BEGIN WORK;

ALTER TABLE rma_request_detail_status_log DROP CONSTRAINT rma_request_detail_status_log_rma_request_detail_id_fkey;
ALTER TABLE rma_request_detail_status_log ADD CONSTRAINT rma_request_detail_status_log_rma_request_detail_id_fkey
    FOREIGN KEY (rma_request_detail_id) REFERENCES rma_request_detail(id) ON DELETE CASCADE DEFERRABLE;

COMMIT WORK;
