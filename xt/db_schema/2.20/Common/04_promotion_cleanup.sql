BEGIN;
    
    --Fix French promotion pack
    UPDATE promotion_type 
    SET product_type = 'Tape Measure (Promotional)', weight = '0.026', 
        fabric = 'Plastic', origin = 'China', hs_code = '901780'
    WHERE id = (SELECT id FROM promotion_type WHERE name = 'Welcome Pack - French');
    
    -- Fix German promotion pack
    UPDATE promotion_type 
    SET product_type = 'Tape Measure (Promotional)', weight = '0.026', 
        fabric = 'Plastic', origin = 'China', hs_code = '901780'
    WHERE id = (SELECT id FROM promotion_type WHERE name = 'Welcome Pack - German');
    
    -- Fix Spanish promotion pack
    UPDATE promotion_type 
    SET product_type = 'Tape Measure (Promotional)', weight = '0.026', 
        fabric = 'Plastic', origin = 'China', hs_code = '901780'
    WHERE id = (SELECT id FROM promotion_type WHERE name = 'Welcome Pack - Spanish');
    
    -- Fix Arabic promotion pack
    UPDATE promotion_type 
    SET product_type = 'Tape Measure (Promotional)', weight = '0.026', 
        fabric = 'Plastic', origin = 'China', hs_code = '901780'
    WHERE id = (SELECT id FROM promotion_type WHERE name = 'Welcome Pack - Arabic');
    
    -- Fix English promotion pack
    UPDATE promotion_type 
    SET product_type = 'Tape Measure (Promotional)', weight = '0.026', 
        fabric = 'Plastic', origin = 'China', hs_code = '901780'
    WHERE id = (SELECT id FROM promotion_type WHERE name = 'Welcome Pack - English');
    
    
COMMIT;