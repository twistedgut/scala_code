--
-- ECO-1305
--
-- bring season conversion rates into line with web app DB
--
-- first, fix the schema definition
--

BEGIN WORK;

ALTER
TABLE season_conversion_rate
   ALTER
  COLUMN conversion_rate
    TYPE NUMERIC(10,4)
    ;

COMMIT WORK;
