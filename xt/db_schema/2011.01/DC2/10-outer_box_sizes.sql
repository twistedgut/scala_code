BEGIN;

update box set weight='0.33',volumetric_weight='0.95',length='9.06', width='7.17', height='4.25' where channel_id=6 and box ilike 'Outer 17';
update box set weight='0.33',volumetric_weight='1.49',length='15.67',width='5.91', height='3.62' where channel_id=6 and box ilike 'Outer 18';
update box set weight='0.35',volumetric_weight='1.39',length='13.78',width='9.84', height='3.74' where channel_id=6 and box ilike 'Outer 19';
update box set weight='0.46',volumetric_weight='2.20',length='17.32',width='11.81',height='3.94' where channel_id=6 and box ilike 'Outer 20';
update box set weight='0.64',volumetric_weight='3.53',length='17.52',width='13.58',height='5.43' where channel_id=6 and box ilike 'Outer 21';
update box set weight='0.95',volumetric_weight='7.26',length='21.46',width='16.14',height='7.68' where channel_id=6 and box ilike 'Outer 22';

COMMIT;
