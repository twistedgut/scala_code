BEGIN;

INSERT INTO authorisation_sub_section (authorisation_section_id, sub_section, ord) VALUES (
    (SELECT id FROM authorisation_section WHERE section = 'Fulfilment'),
    'Fulfilment Overview',
    (
        SELECT MAX(ord) + 10 FROM authorisation_sub_section
        WHERE authorisation_section_id = (
            SELECT id FROM authorisation_section WHERE section = 'Fulfilment'
        )
    )
);

CREATE INDEX idx_shipment_sla_cutoff ON shipment(sla_cutoff);

COMMIT;
