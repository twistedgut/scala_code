BEGIN;

UPDATE public.country SET code = 'TP' WHERE country = 'East Timor';

UPDATE public.country SET code = 'TG' WHERE country = 'Papua New Guinea';
UPDATE public.country SET code = 'IC' WHERE country = 'Canary Islands';


INSERT INTO country (
    id, code, country, sub_region_id, shipment_type_id, proforma,
    returns_proforma, currency_id, shipping_zone_id
) VALUES (
    180, 'GH', 'Ghana',6,4,4,4,0,12
);

INSERT INTO country (
    id, code, country, sub_region_id, shipment_type_id, proforma,
    returns_proforma, currency_id, shipping_zone_id
) VALUES (
    181, 'JE', 'Jersey',6,4,4,4,0,12
);

INSERT INTO country (
    id, code, country, sub_region_id, shipment_type_id, proforma,
    returns_proforma, currency_id, shipping_zone_id
) VALUES (
    182, 'GG', 'Guernsey',6,4,4,4,0,12
);

--
UPDATE country_shipping_charge SET country_id = 181 WHERE country_id = 90;
UPDATE returns_charge SET country_id = 181 WHERE country_id = 90;


DELETE FROM public.country WHERE country = 'Channel Islands';

UPDATE public.country SET country = 'St Barthelemy' WHERE id = 175;

INSERT INTO country (
    id, code, country, sub_region_id, shipment_type_id, proforma,
    returns_proforma, currency_id, shipping_zone_id
) VALUES (
    176, 'YE', 'Yemen',8,5,4,4,1,12
);

UPDATE country_shipping_charge SET country_id = 176 WHERE country_id = 175;


-- sort st barthelemy

UPDATE public.country SET
code = 'BL',
sub_region_id = 4,
shipment_type_id = 5,
proforma = 4,
returns_proforma = 4,
currency_id = 0
WHERE
country = 'St Barthelemy';


COMMIT;
