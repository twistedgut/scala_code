--  Add foreign keys to container
BEGIN;

    -- name change to make pre-existing stand-alone
    -- container column look like a foreign key

    ALTER TABLE public.shipment_item
         RENAME container
             TO container_id
          ;

    INSERT
      INTO container (id, status_id)
    SELECT DISTINCT
           container_id  AS id,
           cs.id         AS status_id
      FROM shipment_item    si,
           container_status cs
     WHERE si.container_id IS NOT NULL
       AND cs.name = 'Picked Items'
        ;

    ALTER TABLE shipment_item
      ADD FOREIGN KEY (container_id)
      REFERENCES container(id)
      DEFERRABLE
      ;

COMMIT;
