BEGIN;

--
-- Create a new shipment class attribute
--

INSERT INTO sos.shipment_class_attribute (name) VALUES ('Sale');

--
-- Link it to a processing time
--

INSERT INTO sos.processing_time (class_attribute_id, processing_time) VALUES
    (
        (
            SELECT id
            FROM   sos.shipment_class_attribute
            WHERE  name = 'Sale'
        ),
        '24:00:00'
    );

--
-- Make these columns mandatory (Boy Scout)
--

ALTER TABLE sos.processing_time_override
    ALTER COLUMN major_id SET NOT NULL,
    ALTER COLUMN minor_id SET NOT NULL;

--
-- Provide the overrides
--

INSERT INTO sos.processing_time_override (major_id, minor_id) VALUES
    -- Premier (Daytime)
    (
        (
            SELECT id
            FROM   sos.processing_time
            WHERE  class_id = (
                SELECT id
                FROM   sos.shipment_class
                WHERE  api_code = 'PREMIER_DAYTIME'
            )
        ),
        (
            SELECT id
            FROM   sos.processing_time
            WHERE  class_attribute_id = (
                SELECT id
                FROM   sos.shipment_class_attribute
                WHERE  name = 'Sale'
            )
        )
    ),
    -- Premier (Evening)
    (
        (
            SELECT id
            FROM   sos.processing_time
            WHERE  class_id = (
                SELECT id
                FROM   sos.shipment_class
                WHERE  api_code = 'PREMIER_EVENING'
            )
        ),
        (
            SELECT id
            FROM   sos.processing_time
            WHERE  class_attribute_id = (
                SELECT id
                FROM   sos.shipment_class_attribute
                WHERE  name = 'Sale'
            )
        )
    );

COMMIT;
