-- Create new table 'return_removal_reason' containing reasons for removals

BEGIN WORK;

CREATE TABLE return_removal_reason (
	id serial NOT NULL,
	name CHARACTER VARYING(255) NOT NULL,
	CONSTRAINT return_removal_reason_pkey PRIMARY KEY (id),
	CONSTRAINT return_removal_reason_name_uniq UNIQUE (name)
);
ALTER TABLE return_removal_reason OWNER TO postgres;
GRANT ALL ON TABLE return_removal_reason TO postgres;
GRANT ALL ON TABLE return_removal_reason TO www;

COMMIT WORK;

-- Populate Table

BEGIN WORK;

INSERT INTO return_removal_reason VALUES ( default, 'RTO' );
INSERT INTO return_removal_reason VALUES ( default, 'Main Stock' );
INSERT INTO return_removal_reason VALUES ( default, 'Jimmy Choo' );
INSERT INTO return_removal_reason VALUES ( default, 'Different AWB Used' );
INSERT INTO return_removal_reason VALUES ( default, 'Other' );

COMMIT WORK;
