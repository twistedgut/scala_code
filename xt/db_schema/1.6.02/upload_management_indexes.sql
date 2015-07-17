--
-- Add indexes to optimise some of the upload management queries 
-- 
--

begin;

    create index list_item_listitem_id on product.list_item (listitem_id);
    create index image_product_id on photography.image (product_id);
    create index image_note_image_id on photography.image_note (image_id);

commit;
