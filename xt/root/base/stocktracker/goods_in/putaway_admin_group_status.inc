[%# See DCA-907 for requirements description %]

[%# NOTE: Nothing printable should be output from this template (except warnings),
    the only action is to set the 'group_display_status' and 'show_sku_discrepancy' variable

    This logic should go to model layer.
%]

[% group_display_status = 'Undetermined' %]

[% IF NOT containers.size %]
    [%# Shouldn't appear on the page %]
    [% group_display_status = 'Not Started' %]
    [% RETURN %]
[% END %]

[%  advices_sent = 0
    advices_completed = 0
    containers_in_progress = 0
%]

[% FOREACH container IN containers %]
    [% IF container.status_id == db_constant('PUTAWAY_PREP_CONTAINER_STATUS__FAILURE') %]
        [%# If any have failed, that's all we care about for the whole group %]
        [% group_display_status = 'Failed Advice' %]
        [% RETURN %]
    [% END %]

    [% IF container.status_id == db_constant('PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS') %]
        [% containers_in_progress = containers_in_progress + 1 %]
    [% END %]

    [% IF container.status_id == db_constant('PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT') %]
        [% advices_sent = advices_sent + 1 %]
    [% END %]

    [% IF container.status_id == db_constant('PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE') %]
        [% advices_sent = advices_sent + 1 %]
        [% advices_completed = advices_completed + 1 %]
    [% END %]

    [%# TODO: DCA-46: Deal with any new status we invent for that %]
[% END %]

[% IF advices_sent %]
    [% IF (
        (putaway_prep_group_row.is_scanned_matches_expected) &&
        (advices_sent == advices_completed) &&
        (containers_in_progress == 0)
    ) %]
        [%# Shouldn't appear on the page %]
        [% group_display_status = 'Complete' %]
        [% RETURN %]
    [% END %]

    [% IF putaway_prep_group_row.is_problem_on_putaway_admin %]
        [%
            group_display_status = 'Problem'
            show_sku_discrepancy = 1
        %]
        [% RETURN %]
    [% END %]

    [% IF putaway_prep_group_row.is_scanned_matches_expected %]
        [% group_display_status = 'Awaiting Putaway' %]
        [% RETURN %]
    [% END %]
    [% IF putaway_prep_group_row.is_part_complete_on_putaway_admin_page %]
        [%
            group_display_status = 'Part Complete'
            show_sku_discrepancy = 1
        %]
        [% RETURN %]
    [% END %]
[% END %]

[% IF containers_in_progress %]
    [% group_display_status = 'In Progress' %]
    [% RETURN %]
[% END %]

[%# We're not expecting to get this far, but sometimes unexpected things happen %]
[% FILTER stderr %]
Could not determine a status for group '[% group_id %]'
[% END %]

[%
    group_display_status = 'Unknown'
    show_sku_discrepancy = 1
%]
