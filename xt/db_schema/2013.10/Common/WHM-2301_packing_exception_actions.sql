-- WHM-2301 Add action constants for packing exceptions
BEGIN;
    CREATE TABLE packing_exception_action (
        id INTEGER PRIMARY KEY NOT NULL,
        name TEXT NOT NULL UNIQUE
    );
    ALTER TABLE packing_exception_action OWNER TO www;
    COMMENT ON TABLE packing_exception_action IS 'Exception actions that can be taken during Packing or Packing Exception';
    INSERT INTO packing_exception_action (id, name) VALUES
        ( 1, 'Faulty' ),
        ( 2, 'Missing' )
    ;
    ALTER TABLE shipment_item_status_log
        ADD COLUMN packing_exception_action_id INTEGER REFERENCES packing_exception_action(id)
    ;
COMMIT;
