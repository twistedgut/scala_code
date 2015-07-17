-- Create new table called 'carrier_box_weight' that holds the weight bounderies
-- for each box per carrier per sales channel

BEGIN WORK;

CREATE TABLE carrier_box_weight (
	id				SERIAL,
	carrier_id		INTEGER REFERENCES carrier (id) NOT NULL,
	box_id			INTEGER REFERENCES box (id) NOT NULL,
	channel_id		INTEGER REFERENCES channel (id) NOT NULL,
	service_name	CHARACTER VARYING (255) NOT NULL,
	weight			DECIMAL(6,2) NOT NULL,
	CONSTRAINT cbw_unique_idx UNIQUE (carrier_id,box_id,channel_id,service_name)
);
ALTER TABLE carrier_box_weight OWNER TO postgres;
GRANT ALL ON TABLE carrier_box_weight TO postgres;
GRANT ALL ON TABLE carrier_box_weight TO www;

COMMIT WORK;
