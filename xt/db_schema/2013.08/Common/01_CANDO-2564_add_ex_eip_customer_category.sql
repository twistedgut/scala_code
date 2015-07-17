-- Task:        CANDO-2564
-- Sub-Task     CANDO-2591
-- Description: Add a new customer category called 'Ex - EIP' under the
--              customer class 'None'.

BEGIN WORK;

INSERT INTO customer_category (
    category,
    discount,
    is_visible,
    customer_class_id,
    fast_track
) VALUES (
    'Ex - EIP',
    0,
    TRUE,
    ( SELECT id FROM customer_class WHERE class = 'None' ),
    FALSE
);

COMMIT WORK;

