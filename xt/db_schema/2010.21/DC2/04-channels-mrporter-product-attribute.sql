BEGIN;


INSERT INTO product.attribute (
id, name, attribute_type_id, deleted, synonyms, manual_sort, page_id, channel_id
) VALUES (
default, 'Unknown', 1, false, null, false, null, 6
);

INSERT INTO product.attribute (
id, name, attribute_type_id, deleted, synonyms, manual_sort, page_id, channel_id
) VALUES (
default, 'Unknown', 2, false, null, false, null, 6
);

INSERT INTO product.attribute (
id, name, attribute_type_id, deleted, synonyms, manual_sort, page_id, channel_id
) VALUES (
default, 'Unknown', 3, false, null, false, null, 6
);


COMMIT;
