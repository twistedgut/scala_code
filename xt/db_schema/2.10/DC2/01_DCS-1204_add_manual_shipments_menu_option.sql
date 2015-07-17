-- Adds a new menu options for DC2 only called Manual Shipments which will point to the Order/Fulfilment/ShipmentsList.pm module.

BEGIN WORK;

INSERT INTO authorisation_sub_section ( authorisation_section_id, sub_section, ord ) VALUES (
    (SELECT id FROM authorisation_section WHERE section = 'Fulfilment'),
    'Invalid Address Shipments',
    (SELECT MAX(ord)+1
     FROM authorisation_sub_section
     WHERE authorisation_section_id = (SELECT id FROM authorisation_section WHERE section = 'Fulfilment')
    )
)
;

COMMIT WORK;
