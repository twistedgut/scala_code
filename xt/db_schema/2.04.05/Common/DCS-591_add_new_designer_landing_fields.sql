-- Add new Designer fields and templates and also 
-- add a new column to the templates to indicate
-- templates relevant to the Designer Landing pages

BEGIN WORK;

ALTER TABLE web_content.template ADD COLUMN designer_landing BOOLEAN;
UPDATE web_content.template
	SET designer_landing = false
;
ALTER TABLE web_content.template ALTER COLUMN designer_landing SET NOT NULL;

UPDATE web_content.template
	SET designer_landing = true
WHERE name IN ('Standard Designer Landing Page','Designer Focus')
;

COMMIT WORK;

BEGIN WORK;

INSERT INTO web_content.template VALUES ( 61, 'Video Designer Landing Page', '', true );
INSERT INTO web_content.template VALUES ( 62, 'Featured Product Designer Landing Page', '', true );

INSERT INTO web_content.field VALUES ( 128, 'Designer Runway Video' );
INSERT INTO web_content.field VALUES ( 129, 'FP One - PID' );
INSERT INTO web_content.field VALUES ( 130, 'FP One - Image Type' );
INSERT INTO web_content.field VALUES ( 131, 'FP Two - PID' );
INSERT INTO web_content.field VALUES ( 132, 'FP Two - Image Type' );
INSERT INTO web_content.field VALUES ( 133, 'FP Three - PID' );
INSERT INTO web_content.field VALUES ( 134, 'FP Three - Image Type' ); 

COMMIT WORK;

-- back fill current designers with new fields

BEGIN WORK;

INSERT INTO web_content.content (instance_id,field_id,content)
SELECT  wcc.instance_id AS instance_id,
        wcf.id AS field_id,
        ''
FROM    web_content.content wcc
		JOIN web_content.instance wci ON wci.id = wcc.instance_id
		JOIN web_content.page wcp ON wcp.id = wci.page_id
		JOIN web_content.template wct ON wct.id = wcp.template_id AND wct.designer_landing = true,
        web_content.field wcf
WHERE   wcf.id BETWEEN 128 AND 134
GROUP BY 1,2
ORDER BY 1,2
;

COMMIT WORK;
