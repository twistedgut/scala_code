-- APAC: Create DC3 distribution centre.

BEGIN WORK;

INSERT INTO distrib_centre (
    id,
    name
) VALUES (
    3,
    'DC3'
);

COMMIT;

