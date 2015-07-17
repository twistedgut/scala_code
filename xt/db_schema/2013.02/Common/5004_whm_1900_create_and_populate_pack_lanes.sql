-- WHM-1900: Create and populate pack_lane (and related) tables

BEGIN WORK;


-- create the tables...
CREATE TABLE pack_lane_type (
	pack_lane_type_id integer PRIMARY KEY,
	name varchar(255) NOT NULL UNIQUE,
    can_have_attributes boolean NOT NULL DEFAULT true
);

CREATE TABLE pack_lane_attribute (
	pack_lane_attribute_id integer PRIMARY KEY,
	name varchar(255) NOT NULL UNIQUE
);

CREATE TABLE pack_lane (
	pack_lane_id integer PRIMARY KEY,
    human_name varchar(255) NOT NULL,
	internal_name varchar(255) NOT NULL UNIQUE,
    capacity integer NOT NULL,
    active boolean NOT NULL,
    type integer NOT NULL references pack_lane_type(pack_lane_type_id)
);

CREATE TABLE pack_lane_has_attribute (
	pack_lane_id integer NOT NULL references pack_lane(pack_lane_id),
    pack_lane_attribute_id integer NOT NULL references pack_lane_attribute(pack_lane_attribute_id),
    PRIMARY KEY(pack_lane_id, pack_lane_attribute_id)
);

ALTER TABLE public.pack_lane_type OWNER TO www;
ALTER TABLE public.pack_lane_attribute OWNER TO www;
ALTER TABLE public.pack_lane OWNER TO www;
ALTER TABLE public.pack_lane_has_attribute OWNER TO www;

-- add common data
INSERT INTO pack_lane_type VALUES(1, 'Single');
INSERT INTO pack_lane_type VALUES(2, 'Multi-Tote');
INSERT INTO pack_lane_type VALUES(3, 'No Read', false);
INSERT INTO pack_lane_type VALUES(4, 'Seasonal');

INSERT INTO pack_lane_attribute VALUES(1, 'Sample');
INSERT INTO pack_lane_attribute VALUES(2, 'Premier');

COMMIT WORK;
