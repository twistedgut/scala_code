-- CANDO-8609: Add a 'customer_issue_type_category' table linked to the
-- 'customer_issue_type' table.

BEGIN WORK;

-- Create the new table category.

CREATE TABLE public.customer_issue_type_category (
    id                  SERIAL PRIMARY KEY,
    description         VARCHAR(255) NOT NULL UNIQUE,
    description_visible BOOLEAN NOT NULL DEFAULT TRUE,
    display_sequence    INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE public.customer_issue_type_category OWNER TO www;

-- Insert the new categories.

INSERT INTO public.customer_issue_type_category (
    description,
    description_visible,
    display_sequence
) VALUES
    ( 'Unknown', FALSE, 1 ),
    ( 'Stock Discrepancy', TRUE, 2 );

-- Add the new columns to the current table.

ALTER TABLE public.customer_issue_type
    ADD COLUMN category_id      INTEGER REFERENCES public.customer_issue_type_category(id),
    ADD COLUMN display_sequence INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN enabled          BOOLEAN NOT NULL DEFAULT TRUE;

-- Move ALL current Issue Types into the "Unknown" category.

UPDATE  public.customer_issue_type
SET     category_id = (
            SELECT  id
            FROM    public.customer_issue_type_category
            WHERE   description = 'Unknown'
        );

-- Make the "category_id" column of the "public.customer_issue_type" NOT NULL.

ALTER TABLE public.customer_issue_type
    ALTER COLUMN category_id SET NOT NULL;

-- Retire the Issue Types that are no longer required.

UPDATE  public.customer_issue_type
SET     enabled = FALSE
WHERE   group_id = (
            SELECT  id
            FROM    public.customer_issue_type_group
            WHERE   description = 'Cancellation Reasons'
        )
        AND description IN (
            'Stock discrepancy',
            'Size Change - Stock Discrepancy'
        );

-- Create the new Stock Discrepency Issue Types, under the "Stock Discrepancy"
-- category.

INSERT INTO public.customer_issue_type (
    group_id,
    description,
    pws_reason,
    category_id,
    display_sequence,
    enabled
) VALUES (
    ( SELECT id FROM public.customer_issue_type_group WHERE description = 'Cancellation Reasons' ),
    'Short pick (Item not in location)',
    NULL,
    ( SELECT id FROM public.customer_issue_type_category WHERE description = 'Stock Discrepancy' ),
    1,
    TRUE
),(
    ( SELECT id FROM public.customer_issue_type_group WHERE description = 'Cancellation Reasons' ),
    'Faulty, last unit in stock',
    NULL,
    ( SELECT id FROM public.customer_issue_type_category WHERE description = 'Stock Discrepancy' ),
    2,
    TRUE
),(
    ( SELECT id FROM public.customer_issue_type_group WHERE description = 'Cancellation Reasons' ),
    'Wrong item or size (mislabelled), last unit in stock',
    NULL,
    ( SELECT id FROM public.customer_issue_type_category WHERE description = 'Stock Discrepancy' ),
    3,
    TRUE
),(
    ( SELECT id FROM public.customer_issue_type_group WHERE description = 'Cancellation Reasons' ),
    'Missing after pick',
    NULL,
    ( SELECT id FROM public.customer_issue_type_category WHERE description = 'Stock Discrepancy' ),
    4,
    TRUE
),(
    ( SELECT id FROM public.customer_issue_type_group WHERE description = 'Cancellation Reasons' ),
    'System error',
    NULL,
    ( SELECT id FROM public.customer_issue_type_category WHERE description = 'Stock Discrepancy' ),
    5,
    TRUE
),(
    ( SELECT id FROM public.customer_issue_type_group WHERE description = 'Cancellation Reasons' ),
    'Stock adjustment error',
    NULL,
    ( SELECT id FROM public.customer_issue_type_category WHERE description = 'Stock Discrepancy' ),
    6,
    TRUE
),(
    ( SELECT id FROM public.customer_issue_type_group WHERE description = 'Cancellation Reasons' ),
    'Tote missing In process',
    NULL,
    ( SELECT id FROM public.customer_issue_type_category WHERE description = 'Stock Discrepancy' ),
    7,
    TRUE
),(
    ( SELECT id FROM public.customer_issue_type_group WHERE description = 'Cancellation Reasons' ),
    'Oversell',
    NULL,
    ( SELECT id FROM public.customer_issue_type_category WHERE description = 'Stock Discrepancy' ),
    8,
    TRUE
);

COMMIT WORK;
