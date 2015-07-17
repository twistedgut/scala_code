-- remove the 'Invalid Address Shipments' menu option for DC2 as 'Invalid Shipments' now retrieves all

BEGIN;

DELETE FROM operator_authorisation
    WHERE authorisation_sub_section_id = (
        SELECT id FROM authorisation_sub_section
        WHERE authorisation_section_id = (SELECT id FROM authorisation_section WHERE section = 'Fulfilment')
        AND sub_section = 'Invalid Address Shipments'
    );

DELETE FROM authorisation_sub_section
    WHERE authorisation_section_id = (SELECT id FROM authorisation_section WHERE section = 'Fulfilment')
    AND sub_section = 'Invalid Address Shipments';

COMMIT;
