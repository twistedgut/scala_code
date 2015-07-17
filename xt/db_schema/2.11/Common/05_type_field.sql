-- Add a link between page templates and fields
-- Populate the table with 'Designer Focus' fields

BEGIN;
    CREATE TABLE web_content.type_field (
        type_id  integer NOT NULL REFERENCES web_content.type(id)  DEFERRABLE,
        field_id integer NOT NULL REFERENCES web_content.field(id) DEFERRABLE,
        PRIMARY KEY (type_id,field_id)
    );
    ALTER TABLE web_content.type_field OWNER TO www;
    INSERT INTO web_content.type_field (type_id,field_id)
        SELECT DISTINCT t.id, c.field_id
        FROM web_content.content c
        JOIN web_content.instance i ON c.instance_id=i.id
        JOIN web_content.page p     ON i.page_id=p.id
        JOIN web_content.type t     ON p.type_id=t.id
        WHERE t.name='Designer Focus'
        ORDER BY t.id, c.field_id
    ;
COMMIT;
