-- http://jira/browse/DCS-710
--
-- Rename "Promotions" menu to "NAP Events"
BEGIN;
    UPDATE public.authorisation_section
    SET     section = 'NAP Events'
    WHERE   section = 'Promotion'
    ;
COMMIT;
