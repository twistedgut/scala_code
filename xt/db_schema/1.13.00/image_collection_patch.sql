
-- RTW batch assign needs to shift along one slot to allow for addition of RW image

BEGIN;

alter table photography.image_collection_item drop constraint image_collection_item_image_collection_id_key;

update photography.image_collection_item set image_index = image_index + 1 where image_collection_id = 1;

alter table photography.image_collection_item add constraint image_collection_item_image_collection_id_key unique(image_collection_id, image_index);

COMMIT;