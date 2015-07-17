-- CANDO-2351: Adds Indexes to the 'link_return_arrival__shipment'
--             table to both fields

BEGIN WORK;

CREATE INDEX idx_link_return_arrival__shipment_return_arrival_id ON link_return_arrival__shipment(return_arrival_id);
CREATE INDEX idx_link_return_arrival__shipment_shipment_id ON link_return_arrival__shipment(shipment_id);

COMMIT WORK;
