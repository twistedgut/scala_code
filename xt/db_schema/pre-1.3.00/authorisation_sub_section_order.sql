-- 
-- Adds a column 'ord' to allow DHTML menus to be ordered by an integer index.
-- Sets the default order to be alphabetical, as it currently is.
--

ALTER TABLE authorisation_sub_section
ADD COLUMN ord smallint;

CREATE OR REPLACE FUNCTION "authorisation_sub_section_order_function" ( ) RETURNS void AS $AUTHORISATION_SUB_SECTION_ORDER_FUNCTION$
DECLARE

    o INTEGER := 0;

    authorisation_section_record RECORD;
    authorisation_sub_section_record RECORD;

BEGIN

    FOR authorisation_section_record IN 
    SELECT id 
    FROM authorisation_section 
    ORDER BY id LOOP

        o := 0;

        FOR authorisation_sub_section_record IN 
	SELECT id 
	FROM authorisation_sub_section 
	WHERE authorisation_section_id = authorisation_section_record.id 
	ORDER BY sub_section LOOP

            o := o + 1;

            UPDATE authorisation_sub_section SET 
	        ord = o
            WHERE id = authorisation_sub_section_record.id;

        END LOOP;

    END LOOP;

END;

$AUTHORISATION_SUB_SECTION_ORDER_FUNCTION$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT authorisation_sub_section_order_function( );

ALTER TABLE authorisation_sub_section
ADD CONSTRAINT authorisation_sub_section_authorisation_section_id_ord_key 
UNIQUE ( authorisation_section_id, ord );

DROP FUNCTION authorisation_sub_section_order_function( );

