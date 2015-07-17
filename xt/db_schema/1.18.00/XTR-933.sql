BEGIN;

    -- update items linked to obsolete reasons
    update return_item 
        set customer_issue_type_id = (select id from customer_issue_type where group_id = 7 and description = 'Shape/Size Too Small') 
	where customer_issue_type_id = (select id from customer_issue_type where group_id = 7 and description = 'Required Larger Size');
    
    update return_item 
        set customer_issue_type_id = (select id from customer_issue_type where group_id = 7 and description = 'Shape/Size Too Big') 
	where customer_issue_type_id = (select id from customer_issue_type where group_id = 7 and description = 'Required Smaller Size');
    
    update return_item 
        set customer_issue_type_id = (select id from customer_issue_type where group_id = 7 and description = 'Unknown') 
	where customer_issue_type_id = (select id from customer_issue_type where group_id = 7 and description = 'Customer Defective');

    update return_item 
        set customer_issue_type_id = (select id from customer_issue_type where group_id = 7 and description = 'Unknown') 
	where customer_issue_type_id = (select id from customer_issue_type where group_id = 7 and description = 'Dry Cleaner Damage');

    -- delete obsolete reasons
    delete from customer_issue_type where group_id = 7 and description = 'Required Larger Size';
    delete from customer_issue_type where group_id = 7 and description = 'Required Smaller Size';
    delete from customer_issue_type where group_id = 7 and description = 'Customer Defective';
    delete from customer_issue_type where group_id = 7 and description = 'Dry Cleaner Damage';


    -- amend reason descriptions
    update customer_issue_type set description = 'Dislike fabric / colour' where description = 'Dislike Fabric/Impractical';
    update customer_issue_type set description = 'Not as pictured / described' where description = 'Not As Described/Pictured';
    update customer_issue_type set description = 'Size too big' where description = 'Shape/Size Too Big';
    update customer_issue_type set description = 'Size too small' where description = 'Shape/Size Too Small';
    update customer_issue_type set description = 'Poor fit' where description = 'Fit';
    update customer_issue_type set description = 'Poor quality / value' where description = 'Quality';
    update customer_issue_type set description = 'Defective / Faulty' where description = 'NAP/Designer Defective';
    update customer_issue_type set description = 'Delivery issue' where description = 'Shipping Issues';
    update customer_issue_type set description = 'Unwanted' where description = 'Dislike/Unsuitable';   


    -- create new reason
    insert into customer_issue_type (id, group_id, description) values ( (select max(id) + 1 from customer_issue_type), 7, 'Exchange not available');


COMMIT;
