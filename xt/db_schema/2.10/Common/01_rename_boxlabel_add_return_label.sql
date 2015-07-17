-- This will rename the 'box_label_image' field and add a new field to handle a return label image

BEGIN WORK;

ALTER TABLE shipment_box
    RENAME COLUMN box_label_image TO outward_box_label_image
;
ALTER TABLE shipment_box
    ADD COLUMN return_box_label_image TEXT
;

COMMIT WORK;
