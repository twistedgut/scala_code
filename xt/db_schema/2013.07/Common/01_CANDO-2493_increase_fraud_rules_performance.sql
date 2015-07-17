-- CANDO-2493: Changes that will increase the performance
--             of the new Fraud Rules or CONRAD

BEGIN WORK;

UPDATE fraud.method
    SET method_parameters =
            CASE
                WHEN method_parameters IS NOT NULL THEN
                    REGEXP_REPLACE( method_parameters, '}]', ',"want_original_purchase_value":1}]' )
                ELSE
                    '[{"want_original_purchase_value":1}]'
            END
WHERE   method_to_call IN (
    'total_spend_in_last_n_period',
    'total_spend_in_last_n_period_on_all_channels',
    'get_total_value_in_local_currency'
)
AND     (
    method_parameters NOT LIKE '%want_original_purchase_value%'
 OR method_parameters IS NULL
 OR method_parameters = ''
)
;

COMMIT WORK;
