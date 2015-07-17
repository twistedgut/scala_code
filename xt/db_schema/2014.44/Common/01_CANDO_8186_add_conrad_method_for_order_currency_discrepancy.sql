-- CANDO-8186: Add 'Order Currency Matches Payment Currency' method to CONRAD.

BEGIN WORK;

INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    return_value_type_id,
    processing_cost
) VALUES (
    'Order Currency Matches Payment Currency',
    'Public::Orders',
    'order_currency_matches_psp_currency',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    1
);

COMMIT;

