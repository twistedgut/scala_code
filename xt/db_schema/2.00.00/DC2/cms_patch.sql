

BEGIN;

CREATE SEQUENCE web_content.page_id_seq 
        INCREMENT 1 MINVALUE 15000 MAXVALUE 2147483648 START 15000; 
    ALTER TABLE web_content.page ALTER COLUMN id 
        SET DEFAULT nextval('web_content.page_id_seq'::regclass); 

GRANT ALL ON web_content.page_id_seq TO www;

CREATE SEQUENCE web_content.instance_id_seq 
        INCREMENT 1 MINVALUE 20000 MAXVALUE 2147483648 START 20000; 
    ALTER TABLE web_content.instance ALTER COLUMN id 
        SET DEFAULT nextval('web_content.instance_id_seq'::regclass); 

GRANT ALL ON web_content.instance_id_seq TO www;

COMMIT;


BEGIN;

-- WEB CONTENT PAGE CHANNELISATION
ALTER TABLE web_content.page ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
UPDATE web_content.page SET channel_id = 2;
ALTER TABLE web_content.page ALTER COLUMN channel_id SET NOT NULL;

COMMIT;

BEGIN;

ALTER TABLE web_content.page DROP CONSTRAINT page_page_key_key;
ALTER TABLE web_content.page ADD CONSTRAINT page_page_key_key UNIQUE (page_key,channel_id);

COMMIT;

BEGIN;
-- Function: web_content.log_published_instance()

-- DROP FUNCTION web_content.log_published_instance();

CREATE OR REPLACE FUNCTION web_content.log_published_instance()
  RETURNS trigger AS
$BODY$
DECLARE
    -- Variables
    v_instance_id	INTEGER := NULL;
    v_old_status_id	INTEGER := NULL;
    v_status_id		INTEGER := NULL;
    v_operator_id	INTEGER := NULL;
BEGIN

	v_instance_id	:= NEW.id;
	v_old_status_id	:= OLD.status_id;
	v_status_id	:= NEW.status_id;
	v_operator_id	:= NEW.last_updated_by;

	IF v_old_status_id != 2 AND v_status_id = 2 THEN
        
		INSERT INTO web_content.published_log (
			instance_id, date, operator_id
		) VALUES (
			v_instance_id, current_timestamp, v_operator_id
		);

	END IF;

    RETURN NEW;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
;
ALTER FUNCTION web_content.log_published_instance() OWNER TO postgres;

COMMIT;
