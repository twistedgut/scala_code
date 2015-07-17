--
-- Be able to record the operator who dealt with the orphan item.
--
BEGIN;

ALTER TABLE orphan_item
      ADD COLUMN operator_id integer NOT NULL DEFAULT 1, -- Application user
      ADD COLUMN date timestamp with time zone default CURRENT_TIMESTAMP,
      ADD CONSTRAINT orphan_item_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES operator(id);

UPDATE orphan_item SET date = NULL; -- We don't want the current date on the previous rows.

COMMIT;
