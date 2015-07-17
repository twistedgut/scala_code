-- CANDO-1889: Updates P2 & P3 Emails with CMS Keys

BEGIN WORK;

--
-- P2 Emails
--
UPDATE  correspondence_templates
    SET id_for_cms  =
        CASE name
            WHEN 'DDU Order - Set Up Permanent DDU Terms And Conditions'    THEN 'TT_DDU_PERMANENT_ACCEPTION'
            WHEN 'Authorization code required'                              THEN 'TT_FINANCE_PAYMENT_AUTH_REQUIRED'
            WHEN 'Security Credit - Billing & shipping address different'   THEN 'TT_FINANCE_DIFFERENT_ADDRESSES'
            WHEN 'Security credit - cannot verify billing address'          THEN 'TT_FINANCE_VERIFY_ADDRESS'
            WHEN 'Security Credit - Chase up'                               THEN 'TT_FINANCE_CREDIT_CHASE'
            WHEN 'Security Credit - Final Reminder'                         THEN 'TT_FINANCE_CREDIT_FINAL'
            WHEN 'Security Credit - Order of high value'                    THEN 'TT_FINANCE_HIGH_VALUE_VERIFICATION'
            WHEN 'Security Credit - Wrong Amount Supplied'                  THEN 'TT_FINANCE_CREDIT_SUPPLIED_INCORRECT'
            WHEN 'Send order to billing address'                            THEN 'TT_FINANCE_SHIP_TO_BILLING_ADDRESS'
            ELSE id_for_cms
        END
WHERE   id_for_cms IS NULL
AND     name IN (
    'DDU Order - Set Up Permanent DDU Terms And Conditions',
    'Authorization code required',
    'Security Credit - Billing & shipping address different',
    'Security credit - cannot verify billing address',
    'Security Credit - Chase up',
    'Security Credit - Final Reminder',
    'Security Credit - Order of high value',
    'Security Credit - Wrong Amount Supplied',
    'Send order to billing address'
)
;

--
-- P3 Emails
--
UPDATE  correspondence_templates
    SET id_for_cms  =
        CASE name
            WHEN 'Send order to billing address - Chase Up'                 THEN 'TT_FINANCE_SHIP_TO_BILLING_ADDRESS_CHASE'
            WHEN 'Credit Check'                                             THEN 'TT_FINANCE_CREDIT_CHECK'
            WHEN 'Name and Address Check'                                   THEN 'TT_FINANCE_NAME_ADDRESS_CHECK'
            WHEN 'Name and Address Check - Chase up'                        THEN 'TT_FINANCE_NAME_ADDRESS_CHECK_CHASE'
            WHEN 'Name and Address Check - Final Reminder'                  THEN 'TT_FINANCE_NAME_ADDRESS_CHECK_FINAL'
            WHEN 'Name and Address Check - Same Address Supplied'           THEN 'TT_FINANCE_NAME_ADDRESS_CHECK_SAME'
            WHEN 'Name and Address Check - Wrong Address Supplied 2nd Time' THEN 'TT_FINANCE_NAME_ADDRESS_CHECK_SAME_2'
            WHEN 'Amex - Shipping and Billing Address Different'            THEN 'TT_FINANCE_DIFFERENT_ADDRESSES_AMEX'
            WHEN 'Amex - Shipping and Billing Address Different - Chase up' THEN 'TT_FINANCE_DIFFERENT_ADDRESSES_AMEX_CHASE'
            ELSE id_for_cms
        END
WHERE   id_for_cms IS NULL
AND     name IN (
    'Send order to billing address - Chase Up',
    'Credit Check',
    'Name and Address Check',
    'Name and Address Check - Chase up',
    'Name and Address Check - Final Reminder',
    'Name and Address Check - Same Address Supplied',
    'Name and Address Check - Wrong Address Supplied 2nd Time',
    'Amex - Shipping and Billing Address Different',
    'Amex - Shipping and Billing Address Different - Chase up'
)
;

COMMIT WORK;
