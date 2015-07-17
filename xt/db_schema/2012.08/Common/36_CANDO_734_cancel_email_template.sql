--
-- CANDO-734: Pre-Order cancellation email template

BEGIN WORK;

-- Reset the id seq for the table
SELECT setval(
        'correspondence_templates_id_seq',
        ( SELECT MAX(id) FROM correspondence_templates )
    )
;

--
-- create the Template
--

INSERT INTO correspondence_templates (name,access,content) VALUES
(
    'Pre Order - Cancel',
    0,
'Dear [% salutation %],

[% IF cancel_all_flag -%]
Thank you for letting me know that you wish to cancel your pre-order ([% pf_pre_order_id %]).

[%- ELSE -%]
Thank you for letting me know that you wish to cancel the following items from your pre-order ([% pf_pre_order_id %]):

[%- END %]
[% FOREACH item IN pre_order_items %]
[%-
    SET product = item.variant.product;
    SET size = ( item.variant.designer_size_id ? item.variant.designer_size.size : item.variant.size.size );
    IF product.size_scheme_id && product.size_scheme.short_name;
    THEN;
        size = product.size_scheme.short_name _ '' '' _ size;
    END;
-%]
-- [% product.designer.designer %] [% product.product_attribute.name %], [% size %] (PID [% product.id %])
[% END -%]
[%- IF refund_flag -%]

[% refund_total %] [% refund_currency %] has been refunded to the card originally used when you placed your order.

Please note that card refunds can take up to 10 days to show on your statement due to varying processing times between card issuers.

[%- END -%]

If I can be of any further assistance, please don''t hesitate to contact me.

[% channel_branding.${db_constant(''BRANDING__EMAIL_SIGNOFF'')} %],

[% sign_off %]
'
)
;

COMMIT WORK;
