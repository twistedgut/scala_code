-- Change runway_look type from varchar to boolean
BEGIN;
    
    -- Create new column
    alter table product_attribute add is_runway_look bool;
    alter table product_attribute alter column is_runway_look set default false;
    
    -- Populate new column data from text column
    update product_attribute set is_runway_look=(case when ((runway_look is not null) or (runway_look<>'')) then true else false end);
    
    -- Replace old column with new data
    alter table product_attribute rename column runway_look to old_runway_look_text;
    alter table product_attribute rename column is_runway_look to runway_look;
    
    -- Set new column as not null
    alter table product_attribute alter column runway_look set not null;
    
    -- Drop old data
    alter table product_attribute drop column old_runway_look_text;
        
COMMIT;

