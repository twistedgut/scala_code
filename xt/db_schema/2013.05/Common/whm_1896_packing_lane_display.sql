-- Add Gift Voucher total to 'renumeration' table

BEGIN WORK;

INSERT INTO authorisation_sub_section
    (authorisation_section_id,sub_section,ord)
    VALUES (
        (SELECT id FROM authorisation_section WHERE section = 'Fulfilment'),
        'Pack Lane Activity',
        104);

COMMIT WORK;
