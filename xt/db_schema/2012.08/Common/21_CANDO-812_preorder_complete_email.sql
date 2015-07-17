-- CANDO-812: Pre-Order Comfirmation Email Template

BEGIN WORK;

-- Reset the id seq for the table
SELECT setval(
        'correspondence_templates_id_seq',
        ( SELECT MAX(id) FROM correspondence_templates )
    )
;

INSERT INTO correspondence_templates (name,access,content) VALUES
(
    'Pre Order - Complete',
    0,
'Dear [% salutation %],

Thank you for your pre-order ([% pre_order_id %]) for the following [% IF pre_order_items.size > 1 %]items:[% ELSE %]item:[% END %]

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
[% amount %] [% currency %]

[% IF pre_order_items.size > 1 %]When these styles are in stock they [% ELSE %]When this style is in stock it [% END %]will be dispatched to the address below:

[% address %]

[% amount %] [% currency %] has been debited from your credit card.

Please note that shipping of [% IF pre_order_items.size > 1 %]these items[% ELSE %]this item[% END %] is complimentary. The above price includes any relevant sales taxes and custom duties when shipping to your chosen shipping destination.

[% IF pre_order_items.size > 1 %]These pieces[% ELSE %]This piece[% END %] will be shipped as soon as [% IF pre_order_items.size > 1 %]they arrive [% ELSE %]it arrives [% END %]so I will let you know when you can expect delivery.

In the meantime, if any of the above details are incorrect or if there are any other styles that you are interested in purchasing please let me know.

[% channel_branding.${db_constant(''BRANDING__EMAIL_SIGNOFF'')} %],

[% sign_off %] 
');

COMMIT WORK;
