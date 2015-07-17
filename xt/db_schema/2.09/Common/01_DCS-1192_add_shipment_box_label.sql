-- Add 'box_label_image' field to 'shipment_box' table

BEGIN WORK;

ALTER TABLE shipment_box ADD COLUMN box_label_image TEXT;

COMMIT WORK;
