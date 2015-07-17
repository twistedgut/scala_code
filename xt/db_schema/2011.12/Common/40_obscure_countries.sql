BEGIN;

INSERT INTO public.country (
code, country, sub_region_id, dhl_tariff_zone
) VALUES (
'AS','American Samoa', (SELECT id FROM public.sub_region WHERE sub_region = 'Australasia'), 0
);

INSERT INTO public.country (
code, country, sub_region_id, dhl_tariff_zone
) VALUES (
'FM','Federated States of Micronesia', (SELECT id FROM public.sub_region WHERE sub_region = 'Australasia'), 0
);

INSERT INTO public.country (
code, country, sub_region_id, dhl_tariff_zone
) VALUES (
'MH','Marshall Islands', (SELECT id FROM public.sub_region WHERE sub_region = 'Australasia'), 0
);

INSERT INTO public.country (
code, country, sub_region_id, dhl_tariff_zone
) VALUES (
'PW','Palau', (SELECT id FROM public.sub_region WHERE sub_region = 'Australasia'), 0
);

INSERT INTO public.country (
code, country, sub_region_id, dhl_tariff_zone
) VALUES (
'RE','Reunion Island', (SELECT id FROM public.sub_region WHERE sub_region = 'Australasia'), 0
);

INSERT INTO public.country (
code, country, sub_region_id, dhl_tariff_zone
) VALUES (
'SB','Solomon Islands', (SELECT id FROM public.sub_region WHERE sub_region = 'Australasia'), 0
);


COMMIT;
