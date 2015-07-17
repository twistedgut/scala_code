-- new schema for website category navigation management

BEGIN;

-- create new navigation sections
insert into authorisation_section values (default, 'Web Content');
insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Web Content'), 'Category Landing', 1);
insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Web Content'), 'Designer Landing', 2);
insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Web Content'), 'Search Results', 3);

-- create web content schema

CREATE SCHEMA web_content;
GRANT ALL ON SCHEMA web_content TO www;


-- CMS tables

CREATE TABLE web_content.template (
	id serial primary key,
	name varchar(255) not null unique,
	description varchar(255) not null
);

GRANT ALL ON web_content.template TO www;
GRANT ALL ON web_content.template_id_seq TO www;


INSERT INTO web_content.template VALUES (1, 'Simple page', '');
INSERT INTO web_content.template VALUES (2, 'Velocity Template', '');
INSERT INTO web_content.template VALUES (3, 'Category Home Page', '');
INSERT INTO web_content.template VALUES (4, 'One Page Editorial', 'One Page Editorial');
INSERT INTO web_content.template VALUES (5, 'Default Home Page', 'This is the standard layout for the home page. However you can also add custom navigation graphics.');
INSERT INTO web_content.template VALUES (6, 'Two Page Editorial', 'Two Page Editorial');
INSERT INTO web_content.template VALUES (7, 'Three Page Editorial', 'Three Page Editorial');
INSERT INTO web_content.template VALUES (8, 'Four Page Editorial', 'Four Page Editorial');
INSERT INTO web_content.template VALUES (9, 'Five Page Editorial', '');
INSERT INTO web_content.template VALUES (10, 'Help Page', 'Help Page');
INSERT INTO web_content.template VALUES (11, 'Chloe Boutique Basic Page', 'Chloe Boutique Basic Page');
INSERT INTO web_content.template VALUES (12, 'Custom Category List', 'Use this to produce a list from a manually compiled product category. Can add links donw the left nav.');
INSERT INTO web_content.template VALUES (13, 'About Us', 'About Us');
INSERT INTO web_content.template VALUES (14, 'Nine Page Editorial', 'Nine page editorial');
INSERT INTO web_content.template VALUES (15, 'Six Page Editorial', 'Six page editorial');
INSERT INTO web_content.template VALUES (16, 'Seven Page Editorial', 'Seven page editorial');
INSERT INTO web_content.template VALUES (17, 'eight page editorial', '');
INSERT INTO web_content.template VALUES (18, 'Thirteen Page Editorial', 'Thirteen Page Editorial');
INSERT INTO web_content.template VALUES (19, 'Fourteen Page Editorial', 'Fourteen Page Editorial');
INSERT INTO web_content.template VALUES (20, 'Gifts', '');
INSERT INTO web_content.template VALUES (21, 'Seventeen Page Editorial', 'Seventeen Page Editorial');
INSERT INTO web_content.template VALUES (50, 'Product Category Home Page', 'Product Category Home Page');
INSERT INTO web_content.template VALUES (51, 'Designer Focus', 'Designer Focus'); 
INSERT INTO web_content.template VALUES (52, 'Search Results', 'Search Results'); 

CREATE TABLE web_content.type (
	id serial primary key,
	name varchar(255) not null unique,
	description varchar(255) not null
);

INSERT INTO web_content.type VALUES (1, 'General Help', 'Privacy, security etc.');
INSERT INTO web_content.type VALUES (2, 'Other', 'e-news sign up');
INSERT INTO web_content.type VALUES (3, 'My Account', 'My account pages');
INSERT INTO web_content.type VALUES (4, 'Buying From Us', 'Finance, warranty T&C etc.');
INSERT INTO web_content.type VALUES (5, 'About Us', 'Store finder, company news, contact us.');
INSERT INTO web_content.type VALUES (6, 'Home. Category and Product Pages', 'Home page, category home, product details.');
INSERT INTO web_content.type VALUES (7, 'News and editorial content', 'Content in news article format i.e. linked from listings page.');
INSERT INTO web_content.type VALUES (8, 'eMail', 'eMails');
INSERT INTO web_content.type VALUES (9, 'Single Page Editorial', 'Single Page Editorial');
INSERT INTO web_content.type VALUES (10, 'Magazine Contents', 'Magazine Contents');
INSERT INTO web_content.type VALUES (11, 'Pop Ups', 'Creqate pop up s that do not use the default headers and footers.');
INSERT INTO web_content.type VALUES (12, 'Static Page', 'Static Page');
INSERT INTO web_content.type VALUES (13, 'Help Section', 'Help Section');
INSERT INTO web_content.type VALUES (14, 'Chloe Boutique', 'Chloe Boutique');
INSERT INTO web_content.type VALUES (15, 'Product Category Home Page', 'Product Category Home Page');
INSERT INTO web_content.type VALUES (16, 'Designer Focus', 'Designer Focus');
INSERT INTO web_content.type VALUES (17, 'Search Results', 'Search Results');

GRANT ALL ON web_content.type TO www;
GRANT ALL ON web_content.type_id_seq TO www;


CREATE TABLE web_content.page (
	id integer not null primary key,
	name varchar(255) not null unique,
	type_id integer null references web_content.type(id),
	template_id integer null references web_content.template(id),
	page_key varchar(255) not null unique
);

-- make sure www can use the table
GRANT ALL ON web_content.page TO www;


CREATE TABLE web_content.instance_status (
	id serial primary key,
	status varchar(255) not null unique
);

GRANT ALL ON web_content.instance_status TO www;
GRANT ALL ON web_content.instance_status_id_seq TO www;

INSERT INTO web_content.instance_status VALUES (1, 'Draft');
INSERT INTO web_content.instance_status VALUES (2, 'Publish');
INSERT INTO web_content.instance_status VALUES (3, 'Archived');


CREATE TABLE web_content.instance (
	id integer not null primary key,
	page_id integer not null references web_content.page(id),
	label varchar(255) not null,
	status_id integer not null references web_content.instance_status(id),
	created timestamp not null default current_timestamp,
	created_by integer not null references operator(id),
	last_updated timestamp not null default current_timestamp,
	last_updated_by integer not null references operator(id),
	UNIQUE (page_id, label)
);

-- make sure www can use the table
GRANT ALL ON web_content.instance TO www;



CREATE TABLE web_content.field (
	id serial primary key,
	name varchar(45) not null unique
);

GRANT ALL ON web_content.field TO www;
GRANT ALL ON web_content.field_id_seq TO www;


insert into web_content.field (id, name) values (1, 'Main');
insert into web_content.field (id, name) values (2, 'Title');
insert into web_content.field (id, name) values (3, 'Description');
insert into web_content.field (id, name) values (4, 'Meta');
insert into web_content.field (id, name) values (5, 'Snippet 1');
insert into web_content.field (id, name) values (6, 'elephant');
insert into web_content.field (id, name) values (7, 'textBody');
insert into web_content.field (id, name) values (8, 'Subject');
insert into web_content.field (id, name) values (9, 'HTMLBody');
insert into web_content.field (id, name) values (10, 'Common Elements Top');
insert into web_content.field (id, name) values (11, 'Common Elements Bottom');
insert into web_content.field (id, name) values (12, 'Single Space Promo 1');
insert into web_content.field (id, name) values (13, 'Designer Description');
insert into web_content.field (id, name) values (14, 'Editorial Category List');
insert into web_content.field (id, name) values (15, 'Cover');
insert into web_content.field (id, name) values (16, 'Whats Hot');
insert into web_content.field (id, name) values (17, 'Double Space Promo');
insert into web_content.field (id, name) values (18, 'Single Space Promo 2');
insert into web_content.field (id, name) values (19, 'Custom Nav Folder');
insert into web_content.field (id, name) values (20, 'Page 1');
insert into web_content.field (id, name) values (21, 'Page 2');
insert into web_content.field (id, name) values (22, 'Page 3');
insert into web_content.field (id, name) values (23, 'Page X');
insert into web_content.field (id, name) values (24, 'Page 4');
insert into web_content.field (id, name) values (25, 'Page 5');
insert into web_content.field (id, name) values (26, 'Help Navigation');
insert into web_content.field (id, name) values (27, 'Chloe Top Nav');
insert into web_content.field (id, name) values (28, 'Chloe Bottom Nav');
insert into web_content.field (id, name) values (29, 'Manual Category Left Nav Elements');
insert into web_content.field (id, name) values (30, 'Left Navigation');
insert into web_content.field (id, name) values (31, 'Cat Home Extra Links');
insert into web_content.field (id, name) values (32, 'Page 6');
insert into web_content.field (id, name) values (33, 'Page 7');
insert into web_content.field (id, name) values (34, 'Page 8');
insert into web_content.field (id, name) values (35, 'Page 9');
insert into web_content.field (id, name) values (36, 'Page  X9');
insert into web_content.field (id, name) values (37, 'Keywords');
insert into web_content.field (id, name) values (38, 'Page 10');
insert into web_content.field (id, name) values (39, 'Page 11');
insert into web_content.field (id, name) values (40, 'Page 12');
insert into web_content.field (id, name) values (41, 'Page 13');
insert into web_content.field (id, name) values (42, 'Page 14');
insert into web_content.field (id, name) values (43, 'GB Price Bands');
insert into web_content.field (id, name) values (44, 'US Price Bands');
insert into web_content.field (id, name) values (45, 'EURO Price Bands');
insert into web_content.field (id, name) values (46, 'Page 15');
insert into web_content.field (id, name) values (47, 'Page 16');
insert into web_content.field (id, name) values (48, 'Page 17');
insert into web_content.field (id, name) values (49, 'designerupdateson');
insert into web_content.field (id, name) values (50, 'Right hand promo space');
insert into web_content.field (id, name) values (51, 'Other designers');
insert into web_content.field (id, name) values (52, 'Main Area Image');
insert into web_content.field (id, name) values (53, 'Main Area Link');
insert into web_content.field (id, name) values (54, 'Main Area Alt');
insert into web_content.field (id, name) values (55, 'Top Right Image');
insert into web_content.field (id, name) values (56, 'Top Right Link');
insert into web_content.field (id, name) values (57, 'Top Right Alt');
insert into web_content.field (id, name) values (58, 'Bottom Right Image');
insert into web_content.field (id, name) values (59, 'Bottom Right Link');
insert into web_content.field (id, name) values (60, 'Bottom Right Alt');
insert into web_content.field (id, name) values (61, 'Top RIght Type');
insert into web_content.field (id, name) values (62, 'Top Right Whats Hot List');
insert into web_content.field (id, name) values (63, 'Top Right What''s Hot List');
insert into web_content.field (id, name) values (64, 'Link 1');
insert into web_content.field (id, name) values (65, 'Link 2');
insert into web_content.field (id, name) values (66, 'Link 3');
insert into web_content.field (id, name) values (67, 'Link 4');

insert into web_content.field (id, name) values (68, 'DesCat Block 1 Image');
insert into web_content.field (id, name) values (69, 'DesCat Block 1 URL');
insert into web_content.field (id, name) values (70, 'DesCat Block 2 Image');
insert into web_content.field (id, name) values (71, 'DesCat Block 2 URL');

insert into web_content.field (id, name) values (72, 'Left Nav Link 1 Text');
insert into web_content.field (id, name) values (73, 'Left Nav Link 1 URL');
insert into web_content.field (id, name) values (74, 'Left Nav Link 2 Text');
insert into web_content.field (id, name) values (75, 'Left Nav Link 2 URL');
insert into web_content.field (id, name) values (76, 'Left Nav Link 3 Text');
insert into web_content.field (id, name) values (77, 'Left Nav Link 3 URL');

insert into web_content.field (id, name) values (78, 'Link 1 Text');
insert into web_content.field (id, name) values (79, 'Link 1 URL');
insert into web_content.field (id, name) values (80, 'Link 2 Text');
insert into web_content.field (id, name) values (81, 'Link 2 URL');
insert into web_content.field (id, name) values (82, 'Link 3 Text');
insert into web_content.field (id, name) values (83, 'Link 3 URL');
insert into web_content.field (id, name) values (84, 'Link 4 Text');
insert into web_content.field (id, name) values (85, 'Link 4 URL');
insert into web_content.field (id, name) values (86, 'Link 5 Text');
insert into web_content.field (id, name) values (87, 'Link 5 URL');
insert into web_content.field (id, name) values (88, 'Link 6 Text');
insert into web_content.field (id, name) values (89, 'Link 6 URL');
insert into web_content.field (id, name) values (90, 'Link 7 Text');
insert into web_content.field (id, name) values (91, 'Link 7 URL');
insert into web_content.field (id, name) values (92, 'Link 8 Text');
insert into web_content.field (id, name) values (93, 'Link 8 URL');





CREATE TABLE web_content.content (
	id serial primary key,
	instance_id integer null references web_content.instance(id),
	field_id integer null references web_content.field(id),
	content text not null,
	category_id varchar(50) null default null,
	searchable_product_id integer null references product(id) default null,
	page_snippet_id integer null default null,
	page_list_id integer null default null
);

-- make sure www can use the table
GRANT ALL ON web_content.content TO www;
GRANT ALL ON web_content.content_id_seq TO www;


CREATE TABLE web_content.published_log (
	id serial primary key,
	instance_id integer null references web_content.instance(id),
	date timestamp not null default current_timestamp,
	operator_id integer not null references operator(id)
);

-- make sure www can use the table
GRANT ALL ON web_content.published_log TO www;
GRANT ALL ON web_content.published_log_id_seq TO www;

CREATE OR REPLACE FUNCTION web_content.log_published_instance() RETURNS
    trigger AS '
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

	RAISE NOTICE
            ''OLD: % ; NEW: %'',
            v_old_status_id, v_status_id;

	IF v_old_status_id != 2 AND v_status_id = 2 THEN
        
		INSERT INTO web_content.published_log (
			instance_id, date, operator_id
		) VALUES (
			v_instance_id, current_timestamp, v_operator_id
		);

	END IF;

    RETURN NEW;
END;
' LANGUAGE plpgsql;

CREATE TRIGGER published_log_tgr AFTER UPDATE
ON web_content.instance
    FOR EACH ROW EXECUTE PROCEDURE web_content.log_published_instance();


-- add page id to designers
alter table designer add column page_id integer references web_content.page(id) null;

-- add page id to product.attribute
alter table product.attribute add column page_id integer references web_content.page(id) null;


COMMIT;
