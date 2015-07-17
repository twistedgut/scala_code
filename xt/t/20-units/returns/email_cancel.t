#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 DC3 ) ];

=head1 NAME

email_cancel.t - Test the Email generated when Cancelling an RMA

=head1 DESCRIPTION

This tests the Email that gets generated when Cancelling an Item for an RMA.

#TAGS goodsin return shouldbeunit checkruncondition email

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Email;

use Catalyst::Utils qw/merge_hashes/;

use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :correspondence_templates
    :shipment_type
/;

my $domain = Test::XTracker::Data::Email->get_active_mq_producer;

my $prod_data = Test::XTracker::Data->get_pid_set({
    nap => 2,
    out => 2,
    mrp => 2,
    jc => 2,
}
,{
    dont_ensure_live_or_visible => 1,
});


my $attrs = [
    { price => 100.00,_no_return => 1 },
    { price => 250.00 },
];

foreach my $bis ( 'nap', 'mrp', 'jc' ) {
    test_2_items_only_1_return({business => $bis});
    test_2_items_only_1_return({business => $bis, premier => 1});
}

test_outnet_2_items_only_1_return();

foreach my $bis ( 'nap', 'mrp', 'jc' ) {
    test_2_items_both_returned({business => $bis});
    test_2_items_both_returned({business => $bis, premier => 1});
}


done_testing;

# Some basic tests on the content of the email when there are 2 items on the
# order, but only one is in the return
sub test_2_items_only_1_return {
    my ($args) = @_;

    my $business    = $args->{business};
    my $premier     = $args->{premier} || 0;

    note "'test_2_items_only_1_return' - Testing for Business: $business";

    my $pids = $prod_data->{$business}{pids};

    my ($return, $order, $si) = Test::XTracker::Data->make_rma({
        base => { channel_id => $prod_data->{ $business }->{channel}->id },
        pids        => $prod_data->{$business}{pids},
        attrs       => $attrs,
        num_returns => 2,
    });

    if ($premier) {
        $si->shipment->update({shipment_type_id => $SHIPMENT_TYPE__PREMIER});
    }

    my $content = $domain->render_email( { return => $return }, $CORRESPONDENCE_TEMPLATES__CANCEL_RETURN )->{email_body};

    Test::XTracker::Data::Email->rma_common_email_tests({content => $content, premier => $premier, business => $business, order => $order});
    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests({content => $content, premier => $premier, business => $business, shipment => $order->get_standard_class_shipment, survey => 1 });

    # The RMA only has a single item, test a few key parts
    unlike($content, qr/items/, "Return only contains 1 item");

    # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
    my (@items) = $content =~ /^(- .* - size .*)$/mg;
    cmp_ok(@items, '==', 1, 'email lists 1 item')
        or diag "Found ". scalar @items;
}

sub test_outnet_2_items_only_1_return {

    note "'test_outnet_2_items_only_1_return' - Testing for Business: out";

    my ($return, $order, $si) = Test::XTracker::Data->make_rma({
        base => { channel_id => $prod_data->{out}->{channel}->id },
        pids => $prod_data->{out}->{pids},
        attrs => $attrs,
    });
#    my ($return, $order, $si) = make_rma({channel_id => 3});

    my $content = $domain->render_email( { return => $return }, $CORRESPONDENCE_TEMPLATES__CANCEL_RETURN )->{email_body};

    Test::XTracker::Data::Email->rma_common_email_tests({content => $content, business => 'out', order => $order});
    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests({content => $content, business => 'out', shipment => $order->get_standard_class_shipment}, survey => 1);

    # The RMA only has a single item, test a few key parts
    unlike($content, qr/items/, "Return only contains 1 item");

    # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
    my (@items) = $content =~ /^(- .* - size .*)$/mg;
    cmp_ok(@items, '==', 1, 'email lists 1 item');
}

sub test_2_items_both_returned {
    my ($args) = @_;

    my $business    = $args->{business};
    my $premier     = $args->{premier} || 0;

    note "'test_2_items_both_returned' - Testing for Business: $business";

    my $newattrs = \@{$attrs};
    $newattrs->[0]->{_no_return} = 0;
    # Create a return for both items
    my ($return, $order, $si) = Test::XTracker::Data->make_rma({
        base => { channel_id => $prod_data->{ $business }->{channel}->id },
        pids => $prod_data->{$business}{pids},
        attrs => $newattrs,
    });

    $si->shipment->update({shipment_type_id => $SHIPMENT_TYPE__PREMIER})
      if $premier;

    my $content = $domain->render_email( { return => $return }, $CORRESPONDENCE_TEMPLATES__CANCEL_RETURN )->{email_body};

    Test::XTracker::Data::Email->rma_common_email_tests({content => $content, premier => $premier, business => $business, order => $order});
    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests({content => $content, premier => $premier, business => $business, shipment => $order->get_standard_class_shipment, survey => 1});

    # The RMA only has a single item, test a few key parts
    like($content, qr/items/, "Return only contains 2 item");

    # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
    my (@items) = $content =~ /^(- .* - size .*)$/mg;
    cmp_ok(@items, '==', 2, 'email lists 2 items');
}
1;

