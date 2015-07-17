BEGIN;

INSERT INTO public.business (
name, config_section, url, show_sale_products, email_signoff
) VALUES (
'MrPorter.com', 'MRP', 'www.mrporter.com', false, 'Customer Care'
);

SELECT setval(
   'channel_id_seq',
   ( SELECT MAX(id) FROM public.channel )
); 




COMMIT;
