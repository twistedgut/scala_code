-- Operator Preferences Table
BEGIN WORK;

CREATE TABLE operator_preferences
(
  operator_id integer NOT NULL,
  pref_channel_id integer DEFAULT null,
  default_home_page integer DEFAULT null,
  CONSTRAINT pref_channel_id FOREIGN KEY (pref_channel_id)
      REFERENCES channel (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT operator_id FOREIGN KEY (operator_id)
      REFERENCES operator (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT default_home_page FOREIGN KEY (default_home_page)
      REFERENCES authorisation_sub_section (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT uniq_operator_id UNIQUE (operator_id)
)
WITH (OIDS=TRUE);
ALTER TABLE operator_preferences OWNER TO postgres;
GRANT ALL ON TABLE operator_preferences TO postgres;
GRANT ALL ON TABLE operator_preferences TO www;

COMMIT WORK;
