-- Add a description field and a description_is_live flag to the designer_channel
-- table primarily for desctiption tabs on the outnet product pages or though it
-- will be pushed to both NAP & OUTNET web-sites. Also add a change log for the description.

BEGIN WORK;

ALTER TABLE designer_channel ADD COLUMN description TEXT;
ALTER TABLE designer_channel ADD COLUMN description_is_live BOOLEAN;

COMMIT WORK;

BEGIN WORK;

CREATE TABLE log_designer_description (
	id SERIAL NOT NULL,
	designer_id INTEGER NOT NULL REFERENCES designer(id),
	channel_id INTEGER NOT NULL REFERENCES channel(id),
	operator_id INTEGER NOT NULL REFERENCES operator(id),
	pre_value TEXT,
	post_value TEXT,
	push_to_where CHARACTER NOT NULL,
	date TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
)
;

ALTER TABLE log_designer_description OWNER TO postgres;
GRANT ALL ON TABLE log_designer_description TO postgres;
GRANT ALL ON TABLE log_designer_description TO www;
GRANT ALL ON TABLE log_designer_description_id_seq TO postgres;
GRANT ALL ON TABLE log_designer_description_id_seq TO www;

COMMIT WORK;
