package Test::XT::Flow::Mech::Reporting;

use NAP::policy qw/tt test role/;

requires 'mech';
requires 'note_status';

with 'Test::XT::Flow::AutoMethods';

#
# Push through the samples workflow
# Process documented at http://confluence.net-a-porter.com/display/Black/Sample
#
use Test::XTracker::Data;

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__reporting__inbound_by_action',
    page_description => 'Inbound By Action Distribution Report',
    page_url         => '/reporting/distribution/inbound_by_action',
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__reporting__inbound_by_action_submit',
    form_name        => 'inbound_by_action_search',
    form_description => 'search',
    assert_location  => qr!^/reporting/distribution/inbound_by_action!,
    transform_fields => sub { $_[1] },
);
