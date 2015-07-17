BEGIN;

UPDATE upload.transfer_log_action SET sequence = sequence + 1 WHERE sequence >= 7;

INSERT INTO upload.transfer_log_action VALUES (10, 'Product Markdown', 7);

COMMIT;