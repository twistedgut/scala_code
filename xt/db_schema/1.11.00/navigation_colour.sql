
BEGIN;

CREATE TABLE colour_navigation (
	id serial primary key,
	colour varchar(255) not null unique
);


GRANT ALL ON colour_navigation TO www;
GRANT ALL ON colour_navigation_id_seq TO www;


INSERT INTO colour_navigation VALUES (1, 'Unknown');
INSERT INTO colour_navigation VALUES (2, 'Blacks');
INSERT INTO colour_navigation VALUES (3, 'Multi');
INSERT INTO colour_navigation VALUES (4, 'Neutrals');
INSERT INTO colour_navigation VALUES (5, 'Metallics_and_Grays');
INSERT INTO colour_navigation VALUES (6, 'Brights');
INSERT INTO colour_navigation VALUES (7, 'Browns');
INSERT INTO colour_navigation VALUES (8, 'Blues_and_Greens');


CREATE TABLE navigation_colour_mapping (
	colour_filter_id integer not null references colour_filter(id),
	colour_navigation_id integer not null references colour_filter(id),
	UNIQUE (colour_filter_id, colour_navigation_id)
);


GRANT ALL ON navigation_colour_mapping TO www;

INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Unknown'), (select id from colour_navigation where colour = 'Unknown'));

INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Black'), (select id from colour_navigation where colour = 'Blacks'));

INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Multi'), (select id from colour_navigation where colour = 'Multi'));

INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Neutrals'), (select id from colour_navigation where colour = 'Neutrals'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'White'), (select id from colour_navigation where colour = 'Neutrals'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Clear'), (select id from colour_navigation where colour = 'Neutrals'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Cream'), (select id from colour_navigation where colour = 'Neutrals'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Nude'), (select id from colour_navigation where colour = 'Neutrals'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Pearl'), (select id from colour_navigation where colour = 'Neutrals'));

INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Gold'), (select id from colour_navigation where colour = 'Metallics_and_Grays'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Metallic'), (select id from colour_navigation where colour = 'Metallics_and_Grays'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Silver'), (select id from colour_navigation where colour = 'Metallics_and_Grays'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Gray'), (select id from colour_navigation where colour = 'Metallics_and_Grays'));

INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Purple'), (select id from colour_navigation where colour = 'Brights'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Pink'), (select id from colour_navigation where colour = 'Brights'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Red'), (select id from colour_navigation where colour = 'Brights'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Orange'), (select id from colour_navigation where colour = 'Brights'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Yellow'), (select id from colour_navigation where colour = 'Brights'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Peach'), (select id from colour_navigation where colour = 'Brights'));

INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Brown'), (select id from colour_navigation where colour = 'Browns'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Tortoiseshell'), (select id from colour_navigation where colour = 'Browns'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Tan'), (select id from colour_navigation where colour = 'Browns'));

INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Blue'), (select id from colour_navigation where colour = 'Blues_and_Greens'));
INSERT INTO navigation_colour_mapping VALUES ( (select id from colour_filter where colour_filter = 'Green'), (select id from colour_navigation where colour = 'Blues_and_Greens'));

COMMIT;

