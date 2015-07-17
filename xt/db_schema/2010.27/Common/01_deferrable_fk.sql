BEGIN;
    ALTER TABLE list.item_state
        DROP CONSTRAINT item_state_display_id_fkey,
        ADD FOREIGN KEY (display_id) REFERENCES display.list_itemstate(id) DEFERRABLE,
        DROP CONSTRAINT item_state_type_id_fkey,
        ADD FOREIGN KEY (type_id) REFERENCES list.type(id) DEFERRABLE
    ;
    ALTER TABLE public.channel
        DROP CONSTRAINT channel_business_id_fkey,
        ADD FOREIGN KEY (business_id) REFERENCES public.business(id) DEFERRABLE,
        DROP CONSTRAINT channel_distrib_centre_id_fkey,
        ADD FOREIGN KEY (distrib_centre_id) REFERENCES public.distrib_centre(id) DEFERRABLE
    ;
    ALTER TABLE public.sub_region
        DROP CONSTRAINT sub_region_region_id_fkey,
        ADD FOREIGN KEY (region_id) REFERENCES public.region(id) DEFERRABLE
    ;
    ALTER TABLE public.country
        DROP CONSTRAINT country_currency_id_fkey,
        ADD FOREIGN KEY (currency_id) REFERENCES public.currency(id) DEFERRABLE,
        DROP CONSTRAINT country_shipment_type_id_fkey,
        ADD FOREIGN KEY (shipment_type_id) REFERENCES public.shipment_type(id) DEFERRABLE,
        DROP CONSTRAINT country_shipping_zone_id_fkey,
        ADD FOREIGN KEY (shipping_zone_id) REFERENCES public.shipping_zone(id) DEFERRABLE,
        DROP CONSTRAINT country_sub_region_id_fkey,
        ADD FOREIGN KEY (sub_region_id) REFERENCES public.sub_region(id) DEFERRABLE
    ;
    ALTER TABLE public.customer_category
        DROP CONSTRAINT customer_category_customer_class_id_fkey,
        ADD FOREIGN KEY (customer_class_id) REFERENCES public.customer_class(id) DEFERRABLE
    ;
    ALTER TABLE public.flag
        DROP CONSTRAINT flag_flag_type_id_fkey,
        ADD FOREIGN KEY (flag_type_id) REFERENCES public.flag_type(id) DEFERRABLE
    ;
    ALTER TABLE public.season
        DROP CONSTRAINT season_season_code_fkey,
        ADD FOREIGN KEY (season_code) REFERENCES public.season_lookup(code) DEFERRABLE
    ;
    ALTER TABLE public.std_size
        DROP CONSTRAINT std_size_std_group_id_fkey,
        ADD FOREIGN KEY (std_group_id) REFERENCES public.std_group(id) DEFERRABLE
    ;
COMMIT;
