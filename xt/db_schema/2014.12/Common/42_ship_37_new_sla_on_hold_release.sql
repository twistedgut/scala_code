BEGIN;

    -- Some shipment_hold_reasons allow the SLA to be recalculated once the shipment
    -- has been released from that hold
    ALTER TABLE public.shipment_hold_reason
        ADD COLUMN allow_new_sla_on_release BOOLEAN NOT NULL DEFAULT FALSE;

    UPDATE public.shipment_hold_reason
        SET allow_new_sla_on_release = TRUE
        WHERE reason IN (
            'Acceptance of charges',
            'Change of Address',
            'Customer on Holiday',
            'Customer Request',
            'Incomplete Address',
            'Unable to make contact to organise a delivery time',
            'Prepaid Order',
            'Order placed on incorrect website',
            'Invalid Payment',
            'Invalid payment',
            'Credit Hold - subject to external payment review',
            'External payment failed'
        );

    -- Link hold_logs to status_logs
    ALTER TABLE public.shipment_hold_log
        ADD COLUMN shipment_status_log_id INTEGER REFERENCES public.shipment_status_log(id);

COMMIT;