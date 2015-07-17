BEGIN;

-- set conversion_rate column to match the conversion_rate table

alter table season_conversion_rate alter column conversion_rate  TYPE double precision;


alter table sales_conversion_rate alter column conversion_rate  TYPE double precision;



COMMIT;
