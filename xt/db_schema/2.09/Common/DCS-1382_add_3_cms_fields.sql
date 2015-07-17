-- Add 3 fields for use in CMS: CSS files, Javascript files & Head HTML

BEGIN WORK;

INSERT INTO web_content.field VALUES ( 138, 'CSS files' );
INSERT INTO web_content.field VALUES ( 139, 'Javascript files' );
INSERT INTO web_content.field VALUES ( 140, 'Head HTML' );

COMMIT WORK;
