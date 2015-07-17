BEGIN;

update box set weight='0.15',volumetric_weight='0.95',length='26.4',width='20',height='10.8' where channel_id=5 and box ilike 'Outer 17';
update box set weight='0.15',volumetric_weight='1.49',length='52.4',width='18.5',height='9.2' where channel_id=5 and box ilike 'Outer 18';
update box set height='9.5' where channel_id=5 and box ilike 'Outer 19';

COMMIT;
