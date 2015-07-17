-- add 'Tech Forum' customer category

BEGIN;
    SELECT setval('public.customer_category_id_seq',
                  ( SELECT MAX(id) FROM public.customer_category ));

    INSERT INTO public.customer_category(
        category,
        discount,
        is_visible,
        customer_class_id,
        fast_track
    )
      SELECT 'Tech Forum' AS category,
                      0.0 AS discount,
                     TRUE AS is_visible,
                       id AS customer_class_id,
                     TRUE AS fast_track
        FROM public.customer_class
       WHERE class = 'EIP'
    ;
COMMIT;
