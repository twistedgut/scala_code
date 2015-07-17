/*****************************************************
* PUI-9: Upload process xT integration.
*
* Delete upload transfer log data.
* Insert new transfer log actions.
*
*****************************************************/

BEGIN;

DELETE FROM upload.transfer_log;
SELECT setval('upload.transfer_log_id_seq', 1, false);

DELETE FROM upload.transfer_summary;
SELECT setval('upload.transfer_summary_id_seq', 1, false);

DELETE FROM upload.transfer;
SELECT setval('upload.transfer_id_seq', 1, false);

DELETE FROM upload.transfer_log_action;
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (1, 'Product Data', 1);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (2, 'Product Attributes', 2);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (3, 'Navigation Attributes', 3);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (4, 'List Attributes', 4);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (5, 'Product SKUs', 5);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (6, 'Product Pricing', 6);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (7, 'Product Inventory', 7);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (8, 'Product Reservations', 8);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (9, 'Related Products', 9);
SELECT setval('upload.transfer_log_action_id_seq', (SELECT max(id) FROM upload.transfer_log_action));

COMMIT;