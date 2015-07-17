BEGIN TRANSACTION;

ALTER TABLE prl
ADD   COLUMN container_ready_requires_routing BOOL NOT NULL DEFAULT FALSE;

UPDATE prl
SET    container_ready_requires_routing = TRUE
WHERE  identifier_name = 'goh' OR identifier_name = 'dcd';

COMMIT;
