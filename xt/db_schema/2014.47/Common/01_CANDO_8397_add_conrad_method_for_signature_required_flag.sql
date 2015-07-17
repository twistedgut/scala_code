-- CANDO-8397: Add 'signature required'  related methods to CONRAD.

BEGIN WORK;

INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    return_value_type_id,
    processing_cost
) VALUES (
    'Is Delivery Signature Required',
    'Public::Orders',
    'is_signature_required_for_standard_class_shipment',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    1
);

INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    return_value_type_id,
    processing_cost
) VALUES (
    'Is Delivery Signature NOT Required',
    'Public::Orders',
    'is_signature_not_required_for_standard_class_shipment',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    1
);

COMMIT;

