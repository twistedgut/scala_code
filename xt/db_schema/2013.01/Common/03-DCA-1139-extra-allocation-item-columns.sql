
-- DCA-1139 - Handle Item Picked Messages
--
-- PRL-architecture picking works differently to IWS picking in terms of which
-- messages it gets. This patch allows us to use the AllocationItem table to
-- store the partial information we receive from a PRL on receipt of an Item
-- Picked message - a string for the user who picked it, a date field for when
-- it was picked, and the container in to which it was picked.
--

BEGIN;

-- These values are set once - and only once - by receipt of an ItemPicked msg
-- from the PRL. All values are expected to be null unless the item has been
-- picked.

-- Will always be set using NOW()
ALTER TABLE allocation_item ADD COLUMN picked_at TIMESTAMP WITH TIME ZONE;

-- This holds a string from the PRL containing the picker name - we have no
-- sensible way of mapping it to the XT user, currently. For human consumption
-- only, and set directly from the data in the ItemPicked message.
ALTER TABLE allocation_item ADD COLUMN picked_by VARCHAR(255);

-- We don't link this to container at this point. We'll use this to set the
-- shipment_item's (to which this allocation_item refers) container_id when we
-- get a ContainerReady message in the future, and it's the shipment_item -
-- with all the magic around its `pick_into` method, that'll handle things like
-- creating the container appropriately. This value is simply meant to reflect
-- what was in the message we received.
ALTER TABLE allocation_item ADD COLUMN picked_into VARCHAR(255);

COMMIT;

