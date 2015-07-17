BEGIN;

-- Create a table that holds the fulfilment overview stage for the UI display

CREATE TABLE fulfilment_overview_stage (
    id SERIAL PRIMARY KEY,
    stage TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);
ALTER TABLE fulfilment_overview_stage OWNER TO www;

INSERT INTO fulfilment_overview_stage (stage) VALUES
    ('Awaiting Selection'),
    ('Awaiting Picking'),
    ('Awaiting Packing'),
    ('Awaiting Labelling'),
    ('Awaiting Dispatch'),
    ('Dispatched'),
    ('Not Displayed');

ALTER TABLE shipment_item_status ADD COLUMN fulfilment_overview_stage_id INT REFERENCES fulfilment_overview_stage(id);

UPDATE shipment_item_status SET fulfilment_overview_stage_id = (SELECT id from fulfilment_overview_stage where stage = 'Not Displayed');
UPDATE shipment_item_status SET fulfilment_overview_stage_id = (SELECT id from fulfilment_overview_stage where stage = 'Awaiting Selection') where status = 'New';
UPDATE shipment_item_status SET fulfilment_overview_stage_id = (SELECT id from fulfilment_overview_stage where stage = 'Awaiting Picking')   where status = 'Selected';
UPDATE shipment_item_status SET fulfilment_overview_stage_id = (SELECT id from fulfilment_overview_stage where stage = 'Awaiting Packing')   where status = 'Picked';
UPDATE shipment_item_status SET fulfilment_overview_stage_id = (SELECT id from fulfilment_overview_stage where stage = 'Awaiting Dispatch')  where status = 'Packed';
UPDATE shipment_item_status SET fulfilment_overview_stage_id = (SELECT id from fulfilment_overview_stage where stage = 'Dispatched')         where status = 'Dispatched';

COMMIT;
