-- extend navigation colour mapping to allow a different mapping for Outnet
-- new nav colours and add a channel id to the filter to nav colour mapping

BEGIN;

SELECT setval('colour_navigation_id_seq', (SELECT max(id) + 1 FROM colour_navigation) );
INSERT INTO colour_navigation (colour) VALUES ('Black'); 
INSERT INTO colour_navigation (colour) VALUES ('Blue');
INSERT INTO colour_navigation (colour) VALUES ('Brown');
INSERT INTO colour_navigation (colour) VALUES ('Gold');
INSERT INTO colour_navigation (colour) VALUES ('Gray');
INSERT INTO colour_navigation (colour) VALUES ('Green');
INSERT INTO colour_navigation (colour) VALUES ('Metallic');
INSERT INTO colour_navigation (colour) VALUES ('Nude');
INSERT INTO colour_navigation (colour) VALUES ('Orange');
INSERT INTO colour_navigation (colour) VALUES ('Pink');
INSERT INTO colour_navigation (colour) VALUES ('Purple');
INSERT INTO colour_navigation (colour) VALUES ('Red');
INSERT INTO colour_navigation (colour) VALUES ('Tortoiseshell');
INSERT INTO colour_navigation (colour) VALUES ('White');
INSERT INTO colour_navigation (colour) VALUES ('Yellow');


ALTER TABLE navigation_colour_mapping ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
UPDATE navigation_colour_mapping SET channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER');
ALTER TABLE navigation_colour_mapping ALTER COLUMN channel_id SET NOT NULL;

ALTER TABLE navigation_colour_mapping DROP CONSTRAINT navigation_colour_mapping_colour_filter_id_key;
ALTER TABLE navigation_colour_mapping ADD CONSTRAINT navigation_colour_mapping_colour_filter_id_key UNIQUE(colour_filter_id, colour_navigation_id, channel_id);

ALTER TABLE navigation_colour_mapping DROP CONSTRAINT navigation_colour_mapping_colour_navigation_id_fkey;
ALTER TABLE navigation_colour_mapping ADD CONSTRAINT navigation_colour_mapping_colour_navigation_id_fkey FOREIGN KEY (colour_navigation_id) REFERENCES colour_navigation(id);

INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Black'), (SELECT id FROM colour_navigation WHERE colour = 'Black'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Blue'), (SELECT id FROM colour_navigation WHERE colour = 'Blue'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Brown'), (SELECT id FROM colour_navigation WHERE colour = 'Brown'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Gray'), (SELECT id FROM colour_navigation WHERE colour = 'Gray'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Green'), (SELECT id FROM colour_navigation WHERE colour = 'Green'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Metallic'), (SELECT id FROM colour_navigation WHERE colour = 'Metallic'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Multi'), (SELECT id FROM colour_navigation WHERE colour = 'Multi'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Orange'), (SELECT id FROM colour_navigation WHERE colour = 'Orange'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Pink'), (SELECT id FROM colour_navigation WHERE colour = 'Pink'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Purple'), (SELECT id FROM colour_navigation WHERE colour = 'Purple'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Red'), (SELECT id FROM colour_navigation WHERE colour = 'Red'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Peach'), (SELECT id FROM colour_navigation WHERE colour = 'Orange'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Yellow'), (SELECT id FROM colour_navigation WHERE colour = 'Yellow'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Cream'), (SELECT id FROM colour_navigation WHERE colour = 'White'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Clear'), (SELECT id FROM colour_navigation WHERE colour = 'White'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Nude'), (SELECT id FROM colour_navigation WHERE colour = 'Nude'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Pearl'), (SELECT id FROM colour_navigation WHERE colour = 'White'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Tan'), (SELECT id FROM colour_navigation WHERE colour = 'Brown'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Tortoiseshell'), (SELECT id FROM colour_navigation WHERE colour = 'Tortoiseshell'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'White'), (SELECT id FROM colour_navigation WHERE colour = 'White'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Unknown'), (SELECT id FROM colour_navigation WHERE colour = 'Unknown'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Neutrals'), (SELECT id FROM colour_navigation WHERE colour = 'Nude'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Gold'), (SELECT id FROM colour_navigation WHERE colour = 'Gold'), (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO navigation_colour_mapping VALUES ( (SELECT id FROM colour_filter WHERE colour_filter = 'Silver'), (SELECT id FROM colour_navigation WHERE colour = 'Metallic'), (SELECT id FROM channel WHERE name = 'The Outnet'));

END;



