BEGIN;

    ALTER TABLE public.return ADD COLUMN creation_date TIMESTAMP WITH TIME ZONE;
    ALTER TABLE public.return_item ADD COLUMN creation_date TIMESTAMP WITH TIME ZONE;


    ALTER TABLE customer_issue_type ADD COLUMN pws_reason varchar(255);


    CREATE INDEX idx_customer_issue_type_id ON return_item (customer_issue_type_id);

    -- Before removing the 'Unknown' and 'Exchange not available' return types, set any uses of them to 'Unwanted'
    UPDATE return_item me
       SET customer_issue_type_id = 
            (SELECT type.id FROM customer_issue_type type 
              JOIN customer_issue_type_group type_group ON (type.group_id = type_group.id AND type_group.description = 'Return Reasons')
             WHERE type.description = 'Unwanted'
            )
     WHERE customer_issue_type_id IN 
            (SELECT type.id FROM customer_issue_type type 
              JOIN customer_issue_type_group type_group ON (type.group_id = type_group.id AND type_group.description = 'Return Reasons')
             WHERE type.description IN ('Unknown', 'Exchange not available')
            );

    -- There are some rows in cancelled item that also refer to Unknown.
    UPDATE cancelled_item me
       SET customer_issue_type_id = 
            (SELECT type.id FROM customer_issue_type type 
              JOIN customer_issue_type_group type_group ON (type.group_id = type_group.id AND type_group.description = 'Return Reasons')
             WHERE type.description = 'Unwanted'
            )
     WHERE customer_issue_type_id IN 
            (SELECT type.id FROM customer_issue_type type 
              JOIN customer_issue_type_group type_group ON (type.group_id = type_group.id AND type_group.description = 'Return Reasons')
             WHERE type.description IN ('Unknown', 'Exchange not available')
            );


    UPDATE customer_issue_type
      SET pws_reason = CASE
            WHEN description = 'Wrong Sent Item' THEN 'DELIVERY_ISSUE'
            WHEN description = 'Dislike fabric / colour' THEN 'FABRIC'
            WHEN description = 'Not as pictured / described' THEN 'NOT_AS_DESCRIBED'
            WHEN description = 'Size too big' THEN 'SIZE_TOO_BIG'
            WHEN description = 'Size too small' THEN 'SIZE_TOO_SMALL'
            WHEN description = 'Poor fit' THEN 'POOR_FIT'
            WHEN description = 'Poor quality / value' THEN 'POOR_QUALITY'
            WHEN description = 'Defective / Faulty' THEN 'DEFECTIVE'
            WHEN description = 'Delivery issue' THEN 'DELIVERY_ISSUE'
            WHEN description = 'Unwanted' THEN 'UNWANTED'
            ELSE NULL
          END
      WHERE group_id IN (SELECT id FROM customer_issue_type_group WHERE description = 'Return Reasons');

    UPDATE customer_issue_type
      SET description = CASE
            WHEN description = 'Size too big' THEN 'Too big'
            WHEN description = 'Size too small' THEN 'Too small'
            WHEN description = 'Poor fit' THEN 'It doesn''t fit me'
            WHEN description = 'Not as pictured / described' THEN 'Not as pictured/described'
            WHEN description = 'Dislike fabric / colour' THEN 'Fabric'
            WHEN description = 'Poor quality / value' THEN 'Quality'
            WHEN description = 'Unwanted' THEN 'Just unsuitable'
            WHEN description = 'Defective / Faulty' THEN 'Defective/faulty'
            WHEN description = 'Wrong Sent Item' THEN 'Incorrect item'
            ELSE description
          END
      WHERE group_id IN (SELECT id FROM customer_issue_type_group WHERE description = 'Return Reasons');


    -- The sequence seems to be out of whack on this table.
    SELECT setval('customer_issue_type_id_seq', max(id)) FROM customer_issue_type;

    -- Insert the two new return reasons
    INSERT INTO customer_issue_type (group_id, description, pws_reason)
      SELECT g.id, a.* 
        FROM ( VALUES ('Colour', 'COLOUR'), ('Price', 'PRICE') ) a 
       CROSS JOIN customer_issue_type_group g 
       WHERE g.description = 'Return Reasons'
    ;
    

    DELETE FROM customer_issue_type me USING customer_issue_type_group g 
     WHERE me.group_id = g.id 
       AND g.description = 'Return Reasons'
       AND me.description IN ('Unknown', 'Exchange not available');
COMMIT;
