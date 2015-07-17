ALTER TABLE product.attribute DROP CONSTRAINT attribute_name_key;
ALTER TABLE product.attribute
ADD CONSTRAINT attribute_name_key UNIQUE(name, attribute_type_id, channel_id);
