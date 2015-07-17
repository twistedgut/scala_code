BEGIN;

INSERT INTO list.list (
    name, type_id, status_id, created_by, last_modified_by
) VALUES (
    'The fitnotes list', 6, 1, 1, 1
);

COMMIT;
