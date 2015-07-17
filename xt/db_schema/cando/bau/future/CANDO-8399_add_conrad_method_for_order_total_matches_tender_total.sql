-- CANDO-8399: Add 'Order Total Matches Tender Total' method to CONRAD.

BEGIN WORK;

INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    return_value_type_id,
    processing_cost
) VALUES (
    'Order Total Matches Tender Total',
    'Public::Orders',
    'order_total_matches_tender_total',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    1
);

COMMIT;
