-- Drop redundant tables 

BEGIN;

    drop table message_working ;
    drop table message_actionlog ;
    drop table message_customer_order_case_link ;
    drop table message_actiontype ;
    drop table message_customer_order_link ;
    drop table message_store ;
    drop table message_type ;
    drop table country_category_mapping ;
    drop table message_category ;

COMMIT;
