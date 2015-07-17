BEGIN;

UPDATE prl SET max_allocation_items = 30 WHERE name = 'GOH';
UPDATE prl SET max_allocation_items = 200 WHERE name != 'GOH';

COMMIT;
