#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

email_convert_to_exchange.t - Email Generated when Converting a Return to an Exchange

=head1 DESCRIPTION

Tests the Email that gets generated when Converting a Return (Refund) to an Exchange.

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
    nap => 2,
    out => 2,
    mrp => 2,
    jc => 2,
}
,{
    dont_ensure_live_or_visible => 1,
});


my $attrs = [
    { price => 250.00 },
    { price => 100.00 },
];

for my $business (qw(nap out mrp jc)) {
    test_convert_to_exchange($business);
}

done_testing;

sub test_convert_to_exchange {
    my ($business) = @_;

    my $channel    = $pid_data->{$business}{channel};
    my $pids       = $pid_data->{$business}{pids};
    note $channel->name;

    my ($return, $order, $si) = Test::XTracker::Data->make_rma({
        base => {
            channel_id => $channel->id,
        },
        pids    => $pids,
        attrs   => $attrs
    });

    my $item_info;

    my $var_id = Test::XTracker::Data->get_schema
        ->resultset('Public::Variant')
        ->find_by_sku($pids->[0]->{sku})
        ->id;

    my $content = $domain->render_email( {
        return => $return,
        return_items => {
           $si->id => {
              remove => 1,
              shipment_item_id => $si->id,
              exchange_variant_id => $var_id,
           }
        },
    }, $CORRESPONDENCE_TEMPLATES__CONVERT_TO_EXCHANGE )->{email_body};

    Test::XTracker::Data::Email->rma_common_email_tests({content => $content, business => $business, order => $order});
    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests({content => $content, business => $business, shipment => $order->get_standard_class_shipment});

    # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
    my (@items) = $content =~ /^(- .* - size .*)$/mg;

    # 1 for the old item, one for what to exchange it to
    cmp_ok(@items, '==', 2, 'email lists 2 items')
      or diag $content;
}
1;

