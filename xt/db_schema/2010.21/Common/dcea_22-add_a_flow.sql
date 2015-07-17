BEGIN;

    INSERT INTO flow.next_status(current_status_id, next_status_id)
        VALUES ( (SELECT s.id FROM flow.status s JOIN flow.type t ON s.type_id = t.id WHERE s.name='Main Stock' and t.name='Stock Status'),
                 (SELECT s.id FROM flow.status s JOIN flow.type t ON s.type_id = t.id WHERE s.name='Transfer Pending' and t.name='Stock Status') );

COMMIT;
