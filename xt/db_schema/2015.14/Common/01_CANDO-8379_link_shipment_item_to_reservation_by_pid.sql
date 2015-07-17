--CANDO-8379: Adding new table link_shipment_item__reservation_by_pid


BEGIN WORK;

--  Add column to reservation table for commission cutoff
ALTER TABLE reservation
  ADD COLUMN commission_cut_off_date TIMESTAMP WITH TIME ZONE
;

-- create new link table for reservation pids
CREATE TABLE link_shipment_item__reservation_by_pid (
    shipment_item_id    INTEGER NOT NULL REFERENCES shipment_item(id),
    reservation_id      INTEGER NOT NULL REFERENCES reservation(id),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE link_shipment_item__reservation_by_pid OWNER    TO postgres;
GRANT ALL ON TABLE link_shipment_item__reservation_by_pid   TO postgres;
GRANT ALL ON TABLE link_shipment_item__reservation_by_pid   TO www;

CREATE INDEX link_shipment_item__reservation__shipment_item_by_pid_idx    ON link_shipment_item__reservation_by_pid(shipment_item_id);
CREATE INDEX link_shipment_item__reservation__reservation_by_pid_idx      ON link_shipment_item__reservation_by_pid(reservation_id);

ALTER TABLE link_shipment_item__reservation_by_pid ADD CONSTRAINT link_shipment_item__reservation_by_pid__unique_ref UNIQUE (shipment_item_id, reservation_id);

COMMIT WORK;
