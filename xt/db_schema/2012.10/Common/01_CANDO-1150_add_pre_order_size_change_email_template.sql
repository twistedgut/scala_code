-- CANDO-1150: Adds a new 'Pre Order - Size Change'
--             email correspondence template

BEGIN WORK;

-- Reset the id seq for the table
SELECT setval(
        'correspondence_templates_id_seq',
        ( SELECT MAX(id) FROM correspondence_templates )
    )
;

INSERT INTO correspondence_templates (name, access, content ) VALUES (
    'Pre Order - Size Change',
    0,
'Dear [% salutation %],

Thank you for letting me know that you wish to amend the [% single_item ? ''size'' : ''sizes'' %] of your pre-order - [% pf_pre_order_id %].

From:
[% FOREACH item IN items_changed -%]
[% item.old.item_obj.name %] - size [% item.old.size %]
[% END -%]

To:
[% FOREACH item IN items_changed -%]
[% item.new.item_obj.name %] - size [% item.new.size %]
[% END -%]

I will continue to update you on the status of your pre-order. 

In the meantime, please let me know if I can help you further.

[% channel_branding.${db_constant(''BRANDING__EMAIL_SIGNOFF'')} %],

[% sign_off %]
'
)
;

COMMIT WORK;
