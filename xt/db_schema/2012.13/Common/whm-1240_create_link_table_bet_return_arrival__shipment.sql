--Create link table between return_arrival and shipment
BEGIN;

CREATE TABLE link_return_arrival__shipment(
    return_arrival_id integer NOT NULL references return_arrival(id),
    shipment_id integer NOT NULL references shipment(id)
);

GRANT ALL ON link_return_arrival__shipment TO www;

COMMIT;
