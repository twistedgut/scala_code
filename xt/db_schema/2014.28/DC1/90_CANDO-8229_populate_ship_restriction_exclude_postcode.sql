
--DC1 ONLY
--CANDO-8229: populate ship_restriction_exclude_postcode table

BEGIN WORK;

INSERT INTO ship_restriction_exclude_postcode (ship_restriction_id, postcode,  country_id ) VALUES
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'AB',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'BT',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'DD',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'DG3',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'DG4',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'DG6',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'DG7',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'DG8',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'DG9',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'EH',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'FK',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'G',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'HS',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'IM',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'IV',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'KA',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'KW',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'KY',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'ML',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PA',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PH',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO30',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO31',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO32',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO33',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO34',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO35',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO36',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO37',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO38',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO39',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO40',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'PO41',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'TD',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'TR21',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'TR22',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'TR23',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'TR24',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'TR25',
    (SELECT id FROM country where code='GB')
),
(
    ( SELECT id FROM ship_restriction where code='HZMT_LQ'),
    'ZE',
    (SELECT id FROM country where code='GB')
)
;

COMMIT WORK;
