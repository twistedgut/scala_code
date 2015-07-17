-- LSR-78: Adds a Lower Case Index on the
--         'operator' table for the 'username'

BEGIN WORK;

CREATE INDEX idx_lower_username ON operator( LOWER(username::text) );

COMMIT WORK;
