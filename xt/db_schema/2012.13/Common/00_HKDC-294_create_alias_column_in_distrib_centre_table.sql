-- HKDC-294: Create and populate a new column called 'alias' in the distrib_centre table.

BEGIN WORK;

ALTER TABLE ONLY    distrib_centre
    ADD COLUMN      alias VARCHAR(10);

UPDATE  distrib_centre
SET     alias = 'INTL'
WHERE   name = 'DC1';

UPDATE  distrib_centre
SET     alias = 'AM'
WHERE   name = 'DC2';

UPDATE  distrib_centre
SET     alias = 'APAC'
WHERE   name = 'DC3';

ALTER TABLE ONLY    distrib_centre
    ALTER COLUMN    alias SET NOT NULL,
    ADD CONSTRAINT  distrib_centre_alias_key UNIQUE (alias);

COMMIT WORK;

