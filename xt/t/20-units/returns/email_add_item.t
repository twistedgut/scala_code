#!/usr/bin/env perl
use NAP::policy "tt", 'test';

=head1 NAME

email_add_item.t - Test the Add Item email for RMA

=DESCRIPTION

This will test the Email that is generated when Adding an Item to an RMA.

#TAGS goodsin return shouldbeunit email

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Email;
use Test::XTracker::LoadTestConfig;
use Catalyst::Utils qw/merge_hashes/;

use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :correspondence_templates
    :shipment_type
    :renumeration_type
/;

my $domain = Test::XTracker::Data::Email->get_active_mq_producer;

my $prod_data = Test::XTracker::Data->get_pid_set({
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
    { price => 100.00, _no_return => 1 },
    { price => 100.00, _no_return => 1 },
];


my $REFUND_TYPE_ID;# = $RENUMERATION_TYPE__STORE_CREDIT;
for my $id (0, $RENUMERATION_TYPE__STORE_CREDIT, $RENUMERATION_TYPE__CARD_REFUND) {
    $REFUND_TYPE_ID = $id;

    ok(1, "Renumeration Type: $REFUND_TYPE_ID");

    test_add_1_item('nap');
    test_add_1_item('out');
    test_add_1_item('mrp');
    test_add_1_item('jc');
    test_add_1_item('nap', 'exchange');
    test_add_1_item('out', 'exchange');
    test_add_1_item('mrp', 'exchange');
    test_add_1_item('jc', 'exchange');

    test_2_items_refund_and_exchange('nap');
    test_2_items_refund_and_exchange('out');
    test_2_items_refund_and_exchange('mrp');
    test_2_items_refund_and_exchange('jc');
}

done_testing;

sub test_add_1_item {
    my ($business, $exchange) = @_;

    my $channel = $prod_data->{$business}{channel};
    my $pids    = $prod_data->{$business}{pids};
    note        $channel->name;

    my ($return, $order, $si) = Test::XTracker::Data->make_rma({
        base => {
            channel_id => $channel->id,
        },
        pids => $pids,
        attrs => $attrs
    });

    my $item_info;

    if ($exchange) {
        my $var_id = Test::XTracker::Data->get_schema
            ->resultset('Public::Variant')
            ->find_by_sku($pids->[1]->{sku})
            ->id;
        $item_info = {
            type => 'Exchange',
            reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
            exchange_variant => $var_id,
        };
    }
    else {
        $item_info = {
            type => 'Return',
            reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
        };
    }

    my $content = $domain->render_email( {
        return => $return,
        return_items => {
           $si->id => $item_info,
        },
        __refund_type_id => $REFUND_TYPE_ID,

    }, $CORRESPONDENCE_TEMPLATES__ADD_RETURN_ITEM )->{email_body};
    Test::XTracker::Data::Email->rma_common_email_tests({content => $content, business => $business, order => $order});
    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests({content => $content, business => $business, shipment => $order->get_standard_class_shipment});

    # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
    my (@items) = $content =~ /^(- .* - size .*)$/mg;

    if ($exchange) {
        # 1 item, plus 1 extra line for the exchange item
        cmp_ok(@items, '==', 2, 'email lists 2 items (item to exchange, and what to change it for)')
          or diag $content;
    }
    else {
        cmp_ok(@items, '==', 1, 'email lists 1 item')
          or diag $content;
    }
}

sub test_2_items_refund_and_exchange{
    my ($business) = @_;

    my $channel = $prod_data->{$business}{channel};
    my $pids    = $prod_data->{$business}{pids};
    note        $channel->name;

    my ($return, $order, $si1, $si2) = Test::XTracker::Data->make_rma({
        base => {
            channel_id => $channel->id,
        },
        pids => $pids,
        attrs => $attrs
    });

    my $var_id = Test::XTracker::Data->get_schema
         ->resultset('Public::Variant')
         ->find_by_sku($pids->[1]->{sku})
         #->find_by_sku($pids->[1]->{sku}'48499-096')
         ->id;


    my $content = $domain->render_email( {
        return => $return,
        return_items => {
            $si1->id => {
                type => 'Exchange',
                reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                exchange_variant => $var_id,
            },
            $si2->id => {
                type => 'Return',
                reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
            }

        },
        __refund_type_id => $REFUND_TYPE_ID,

    }, $CORRESPONDENCE_TEMPLATES__ADD_RETURN_ITEM )->{email_body};

    Test::XTracker::Data::Email->rma_common_email_tests({content => $content, business => $business, order => $order});
    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests({content => $content, business => $business, shipment => $order->get_standard_class_shipment});

    # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
    my (@items) = $content =~ /^(- .* - size .*)$/mg;

    # 2 items, plus 1 extra line for the exchange item
    cmp_ok(@items, '==', 3, 'email lists 3 items (item to exchange, and what to change it for)')
      or diag $content;
}
1;
