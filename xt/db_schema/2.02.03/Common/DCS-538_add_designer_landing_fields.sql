-- Add 2 fields and a new template for Designer Landing pages

BEGIN WORK;

INSERT INTO web_content.template VALUES ( 60, 'Standard Designer Landing Page', '' );
INSERT INTO web_content.field VALUES ( 126, 'Designer Name Font Class' );
INSERT INTO web_content.field VALUES ( 127, 'Promo Block Two' );

COMMIT WORK;

BEGIN WORK;

INSERT INTO web_content.content (instance_id,field_id,content)
SELECT	instance_id AS instance_id,
		126 AS field_id,
		''
FROM	web_content.content
GROUP BY 1,2
;

INSERT INTO web_content.content (instance_id,field_id,content)
SELECT	instance_id AS instance_id,
		127 AS field_id,
		''
FROM	web_content.content
GROUP BY 1,2
;

COMMIT WORK;
