--CANDO-2353 : Insert new packaging_type for MRP and NAP channels

BEGIN WORK;

-- Reset the Sequence Id on the Table
SELECT SETVAL('packaging_type_id_seq', (SELECT max(id) FROM packaging_type));

--Insert new packaging type for Givenchy
INSERT INTO packaging_type (sku,name) VALUES ('900111-001','GIVENCHY' );

INSERT INTO packaging_attribute
        ( packaging_type_id, name, public_name, title, public_title, channel_id, description)
    VALUES
        ((SELECT id FROM packaging_type where name='GIVENCHY'),
        'Givenchy Packaging',
        'Givenchy Packaging',
        'Givenchy Packaging',
        'Givenchy Packaging',
        ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
        'Express orders are delivered in signature Givenchy gift boxes.|Premier orders are delivered in signature Givenchy shopping bags.'
        );

INSERT INTO packaging_attribute
        ( packaging_type_id, name, public_name, title, public_title, channel_id, description)
    VALUES
        ((SELECT id FROM packaging_type where name='GIVENCHY'),
        'Givenchy Packaging',
        'Givenchy Packaging',
        'Givenchy Packaging',
        'Givenchy Packaging',
        ( SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
        'Express orders are delivered in signature Givenchy gift boxes.|Premier orders are delivered in signature Givenchy shopping bags.'
        );


COMMIT WORK;
