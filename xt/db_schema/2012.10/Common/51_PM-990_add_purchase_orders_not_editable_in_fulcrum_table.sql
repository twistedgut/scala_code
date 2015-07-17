-- We want to store here all the PO's that were not processed
-- by the XT<->Fulcrum backfill sync process, so that if a
-- PO exists here it can't be edited in fulcrum.
BEGIN;

DROP TABLE IF EXISTS public.purchase_orders_not_editable_in_fulcrum;

CREATE TABLE purchase_orders_not_editable_in_fulcrum (
    "number" text NOT NULL,
    PRIMARY KEY ("number")
);

ALTER TABLE public.purchase_orders_not_editable_in_fulcrum OWNER TO www;

COMMIT;
