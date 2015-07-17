BEGIN;

ALTER TABLE list.item ALTER COLUMN list_id DROP NOT NULL;

ALTER TABLE list.item ADD COLUMN type_id INTEGER REFERENCES list.type(id);


UPDATE list.item SET type_id = 1
WHERE list_id IN (SELECT id FROM list.list WHERE type_id =1);

UPDATE list.item SET type_id = 2
WHERE list_id IN (SELECT id FROM list.list WHERE type_id =2);

UPDATE list.item SET type_id = 3
WHERE list_id IN (SELECT id FROM list.list WHERE type_id =3);

UPDATE list.item SET type_id = 4
WHERE list_id IN (SELECT id FROM list.list WHERE type_id =4);

UPDATE list.item SET type_id = 5
WHERE list_id IN (SELECT id FROM list.list WHERE type_id =5);

UPDATE list.item SET type_id = 6
WHERE list_id IN (SELECT id FROM list.list WHERE type_id =6);


ALTER TABLE list.item ALTER COLUMN type_id SET NOT NULL;


COMMIT;
