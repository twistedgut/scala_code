<!-- TT BEGIN : root/base/stocktracker/goods_in/putaway_admin_container_status.inc -->

[%- IF status_id == db_constant('PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS') -%]
    [% container_display_status = '<!-- nothing displayed -->' %]
[%- ELSIF status_id == db_constant('PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT') -%]
    [% container_display_status = 'Sent' %]
[%- ELSIF status_id == db_constant('PUTAWAY_PREP_CONTAINER_STATUS__FAILURE') -%]
    [% container_display_status = failure_reason %]
[%- ELSIF status_id == db_constant('PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE') -%]
    [% container_display_status = 'Putaway' %]
[%- ELSE -%]
    [%-# We shouldn't actually get this far unless we invent new statuses -%]
    [%-# and forget to add them to the logic above. -%]
    [% container_display_status = 'Unknown' %]
[%- END -%]

<!-- TT END : root/base/stocktracker/goods_in/putaway_admin_container_status.inc -->
