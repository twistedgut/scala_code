
BEGIN;


CREATE OR REPLACE VIEW view_product_upload AS SELECT
    pli.product_id as product_id,
    ll.id as upload_id,
    ll.name as name,
    ll.due as date
FROM
    product.list_item pli, list.item li, list.list ll, list.type lt
WHERE
    pli.listitem_id = li.id
AND 
    li.list_id = ll.id 
AND 
    ll.type_id = lt.id
AND
    lt.name = 'Upload'
;

GRANT ALL ON public.view_product_upload TO www;

COMMIT;