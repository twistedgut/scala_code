#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;

=head1 NAME

email_remove_item.t - Email generated when Removing an Item

=head1 DESCRIPTION

Tests the Email that gets generated when removing an Item from a RMA.

#TAGS goodsin return shouldbeunit email

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Email;

use Catalyst::Utils qw/merge_hashes/;

use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :correspondence_templates
    :shipment_type
    :renumeration_type
/;

my $domain = Test::XTracker::Data::Email->get_active_mq_producer;

my $pid_data = Test::XTracker::Data->get_pid_set({
    nap => 3,
    out => 3,
    mrp => 3,
    jc => 3,
}
,{
    dont_ensure_live_or_visible => 1,
});

my $attrs = [
    { price => 250.00 },
    { price => 100.00 },
];


for my $business (qw(nap out mrp jc)) {
    test_remove_item($business);
}

done_testing;

sub test_remove_item {
    my ($business) = @_;

    my $channel = $pid_data->{$business}{channel};
    my $pids    = $pid_data->{$business}{pids};
    note $channel->name;

    my ($return, $order, $si) = Test::XTracker::Data->make_rma({
        base => {
            channel_id => $channel->id,
        },
        pids => $pids,
        attrs => $attrs
    });

    my $item_info;

    my $content = $domain->render_email( {
        return => $return,
        return_items => {
           $si->id => { remove => 1 }
        },
    }, $CORRESPONDENCE_TEMPLATES__REMOVE_RETURN_ITEM )->{email_body};

    Test::XTracker::Data::Email->rma_common_email_tests({content => $content, business => $business, order => $order});
    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests({content => $content, business => $business, shipment => $order->get_standard_class_shipment});

    # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
    my (@items) = $content =~ /^(- .* - size .*)$/mg;

    cmp_ok(@items, '==', 1, 'email lists 1 item')
      or diag $content;
}
1;
