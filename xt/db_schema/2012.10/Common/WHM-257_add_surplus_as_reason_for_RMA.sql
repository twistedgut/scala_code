-- Add surplus to rma_request_detail_type

BEGIN;
INSERT INTO rma_request_detail_type (type) VALUES ('Surplus');
COMMIT;

