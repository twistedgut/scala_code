BEGIN WORK;

ALTER TABLE orders ADD COLUMN customer_language_preference_id integer REFERENCES language(id);

COMMIT WORK;

