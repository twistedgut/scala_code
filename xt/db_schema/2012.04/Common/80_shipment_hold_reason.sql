BEGIN;

SELECT setval('shipment_hold_reason_id_seq', max(id))
    FROM public.shipment_hold_reason;


INSERT INTO public.shipment_hold_reason (
    reason
) VALUES (
    'Nominated Day possible SLA breach'
);

COMMIT;
