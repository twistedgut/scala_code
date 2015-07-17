-- Purpose: Field to store source of animal skin used for Fish & Wildlife products "Farmed" or "Wild"
--  

BEGIN;

alter table shipping_attribute add column fish_wildlife_source varchar(50);

COMMIT;