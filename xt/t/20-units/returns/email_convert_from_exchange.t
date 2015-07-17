#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;

=head1 NAME

email_convert_from_exchange.t - Email generated when Converting an Exchange to a Return

=head1 DESCRIPTION

Tests the Email that gets generated when Converting an Exchange to a Return.

#TAGS goodsin return shouldbeunit email

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Email;

use Catalyst::Utils qw/merge_hashes/;

use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :correspondence_templates
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

test_convert_to_exchange('nap', $RENUMERATION_TYPE__STORE_CREDIT);
test_convert_to_exchange('out', $RENUMERATION_TYPE__CARD_REFUND);
test_convert_to_exchange('mrp', $RENUMERATION_TYPE__CARD_REFUND);
test_convert_to_exchange('jc', $RENUMERATION_TYPE__CARD_REFUND);

done_testing;

sub test_convert_to_exchange {
    my ($business, $refund_type) = @_;

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
            $si->id => {
                change => 1,
                shipment_item_id => $si->id,
            }
        },
        refund_type_id => $refund_type,
    }, $CORRESPONDENCE_TEMPLATES__CANCEL_EXCHANGE )->{email_body};

    Test::XTracker::Data::Email->rma_common_email_tests({content => $content, business => $business, order => $order});
    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests({content => $content, business => $business, shipment => $order->get_standard_class_shipment});

    # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
    my (@items) = $content =~ /^(- .* - size .*)$/mg;

    cmp_ok(@items, '==', 1, 'email lists 1 item')
      or diag $content;
}
1;
