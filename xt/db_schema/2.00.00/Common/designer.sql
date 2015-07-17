-- Creates a designer_channel table and populates it
-- drops fields page_id & website_state_id from designer table
-- Adds a channel_id field to desiger.attribute table
-- Channelises designer.log_website_state table
-- Creates a dummy Designer Category called 'All designers' for the OUTNET

-- Create table
BEGIN WORK;

CREATE TABLE designer_channel (
	id serial PRIMARY KEY,
	designer_id INTEGER REFERENCES public.designer(id) NOT NULL,
	page_id INTEGER REFERENCES web_content.page(id),
	website_state_id INTEGER REFERENCES designer.website_state(id) NOT NULL,
	channel_id INTEGER REFERENCES public.channel(id) NOT NULL,
	UNIQUE(designer_id,channel_id)
) WITH (OIDS=TRUE)
;
ALTER TABLE designer_channel OWNER TO postgres;
GRANT ALL ON TABLE designer_channel TO postgres;
GRANT ALL ON TABLE designer_channel TO www;

GRANT ALL ON TABLE designer_channel_id_seq TO postgres;
GRANT ALL ON TABLE designer_channel_id_seq TO www;

COMMIT WORK;

-- populate table for NAP
BEGIN WORK;

INSERT INTO designer_channel (designer_id,page_id,website_state_id,channel_id)
SELECT	id,
		page_id,
		website_state_id,
		(SELECT c.id FROM channel c, business b WHERE c.business_id = b.id AND b.config_section = 'NAP') AS channel_id
FROM	designer
ORDER BY id
;

COMMIT WORK;

-- populate for OUTNET
BEGIN WORK;

INSERT INTO designer_channel (designer_id,page_id,website_state_id,channel_id)
SELECT	id,
		NULL,
		1,
		(SELECT c.id FROM channel c, business b WHERE c.business_id = b.id AND b.config_section = 'OUTNET') AS channel_id
FROM	designer
ORDER BY id
;

COMMIT WORK;

-- drop fields from designer table
BEGIN WORK;

ALTER TABLE designer DROP COLUMN page_id;
ALTER TABLE designer DROP COLUMN website_state_id;

COMMIT WORK;

-- add a channel_id to designer.attribute
-- & populate for NAP
BEGIN WORK;

ALTER TABLE designer.attribute ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
UPDATE designer.attribute SET channel_id = (SELECT c.id FROM channel c, business b WHERE c.business_id = b.id AND b.config_section = 'NAP');
ALTER TABLE designer.attribute ALTER COLUMN channel_id SET NOT NULL;

ALTER TABLE designer.attribute DROP CONSTRAINT attribute_name_key;
ALTER TABLE designer.attribute
	ADD CONSTRAINT attribute_name_key UNIQUE(name, attribute_type_id, channel_id);

COMMIT WORK;

-- Channelise designer.log_website_state table
BEGIN WORK;

ALTER TABLE designer.log_website_state ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
UPDATE designer.log_website_state SET channel_id = (SELECT c.id FROM channel c, business b WHERE c.business_id = b.id AND b.config_section = 'NAP');
ALTER TABLE designer.log_website_state ALTER COLUMN channel_id SET NOT NULL;

COMMIT WORK;

-- Create a dummy Designer Category for the OUTNET
BEGIN WORK;

INSERT INTO designer.attribute (name,attribute_type_id,deleted,manual_sort,channel_id) VALUES (
'All-designers',
(SELECT id FROM designer.attribute_type WHERE web_attribute = 'STD_CAT'),
FALSE,
FALSE,
(SELECT c.id FROM channel c, business b WHERE c.business_id = b.id AND b.config_section = 'OUTNET')
);

COMMIT WORK;
