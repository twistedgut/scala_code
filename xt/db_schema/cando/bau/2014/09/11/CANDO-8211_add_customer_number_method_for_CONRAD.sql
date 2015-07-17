--
-- CANDO-8211 Add Customer Number method to CONRAD
--

BEGIN WORK;

INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    return_value_type_id,
    processing_cost
)
VALUES ( 
    'Customer Number is ',
    'Public::Customer',
    'is_customer_number',
    ( select id from fraud.return_value_type where type = 'string' ),
    1
);

COMMIT;
