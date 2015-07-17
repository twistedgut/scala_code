-- CANDO-8364: Add an "enabled" flag to the "public.renumeration_reason" table
-- and insert/disable some reasons.

BEGIN WORK;

-- Add the new "enabled" column.
ALTER TABLE public.renumeration_reason
    ADD COLUMN enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- Insert the new reasons.
INSERT INTO public.renumeration_reason (
    renumeration_reason_type_id,
    reason,
    department_id,
    enabled
)
VALUES
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Additional Fees',
    NULL,
    TRUE
),
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Damaged/Faulty Item Sent',
    NULL,
    TRUE
),
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Return',
    NULL,
    TRUE
),
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Shipping fee refunded',
    NULL,
    TRUE
),
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Item order lost in transit',
    NULL,
    TRUE
),
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Staff/PR discount',
    NULL,
    TRUE
),
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Failed QC/Repairs/Wear and tear',
    NULL,
    TRUE
),
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Missing Part of PID/Wrong Item sent',
    NULL,
    TRUE
),
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Miscellaneous',
    NULL,
    TRUE
),
(
    ( SELECT id FROM public.renumeration_reason_type WHERE type = 'Compensation' ),
    'Security Check',
    -- This reason must only be visible by the Finance department.
    ( SELECT id FROM public.department WHERE department = 'Finance' ),
    TRUE
);

-- Disable the required existing reasons.
UPDATE  public.renumeration_reason
SET     enabled = FALSE
WHERE   reason IN (
            'Size & fit complaint',
            'Style a Friend',
            'Transfer of credit to/from account',
            'VOC',
            'Wrong order received',
            'Faulty Item',
            'RTV',
            'Missing item/order',
            'Part of PID missing',
            'Goodwill gesture',
            'Security Credit'
        );

-- Remove the department restriction for the 'Security Check' reason, which
-- is currently restricted to 'Finance'.
UPDATE  public.renumeration_reason
SET     department_id = NULL
WHERE   reason = 'Security Check';

COMMIT WORK;
