BEGIN;

UPDATE inner_box SET outer_box_id =
  (       SELECT id FROM box WHERE box = 'Unknown'
      and channel_id =
      ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' ) 
  )
WHERE channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' );

COMMIT;
