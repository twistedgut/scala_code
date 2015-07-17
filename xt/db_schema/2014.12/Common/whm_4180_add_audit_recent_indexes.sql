-- WHM-4180 Add missing indexes to audit.recent

BEGIN;
    CREATE INDEX idx_audit_recent_table_schema_table_name_audit_id
        ON audit.recent (table_schema, table_name, audit_id);
COMMIT;
