-- CANDO-1650: Update the number of Outward & Return
--             Proformas that need to be printed
--             for some countries

BEGIN WORK;

-- Set All Countries to be 4 & 4
UPDATE  country
    SET proforma        = 4,
        returns_proforma= 4
;

-- Unknown
UPDATE  country
    SET proforma        = 0,
        returns_proforma= 0
WHERE   country = 'Unknown'
;

-- Kuwait
UPDATE  country
    SET proforma        = 8,
        returns_proforma= 4
WHERE   country = 'Kuwait'
;

-- Hong Kong
UPDATE  country
    SET proforma        = 0,
        returns_proforma= 1
WHERE   country = 'Hong Kong'
;

COMMIT WORK;
