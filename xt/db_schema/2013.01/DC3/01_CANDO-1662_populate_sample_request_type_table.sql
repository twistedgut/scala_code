-- CANDO-1662: Populate the sample_request_type table with the same data from DC1/2.

BEGIN WORK;

INSERT INTO sample_request_type (
    code,
    type,
    bookout_location_id,
    source_location_id
)
VALUES
(
    'prs',
    'Press',
    ( SELECT id FROM location WHERE location = 'Press' ),
    ( SELECT id FROM location WHERE location = 'Press Samples' )
),
(
    'cre',
    'Editorial',
    ( SELECT id FROM location WHERE location = 'Editorial' ),
    ( SELECT id FROM location WHERE location = 'Sample Room' )
),
(
    'crs',
    'Styling',
    ( SELECT id FROM location WHERE location = 'Styling' ),
    ( SELECT id FROM location WHERE location = 'Sample Room' )
),
(
    'cru',
    'Upload',
    ( SELECT id FROM location WHERE location = 'Upload 1' ),
    ( SELECT id FROM location WHERE location = 'Sample Room' )
),
(
    'crp',
    'Pre-Shoot',
    ( SELECT id FROM location WHERE location = 'Pre-Shoot' ),
    ( SELECT id FROM location WHERE location = 'Sample Room' )
);

COMMIT;
