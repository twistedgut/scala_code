BEGIN;

--
-- Provide the overrides
--

INSERT INTO sos.processing_time_override (major_id, minor_id) VALUES
    -- Premier (ALl Day)
    (
        (
            SELECT id
            FROM   sos.processing_time
            WHERE  class_id = (
                SELECT id
                FROM   sos.shipment_class
                WHERE  api_code = 'PREMIER_ALL_DAY'
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
    -- Nominated Day
    (
        (
            SELECT id
            FROM   sos.processing_time
            WHERE  class_id = (
                SELECT id
                FROM   sos.shipment_class
                WHERE  api_code = 'NOMDAY'
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
    -- Express
    (
        (
            SELECT id
            FROM   sos.processing_time
            WHERE  class_attribute_id = (
                SELECT id
                FROM   sos.shipment_class_attribute
                WHERE  name = 'Express'
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
