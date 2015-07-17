#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

possible_nominated_day_breach.t - Test SLA breaches for Nominated Day

=head1 DESCRIPTION

This tests the scripts that send emails for actual and possible nominated day
SLA breaches.

#TAGS fulfilment selection duplication nominatedday checkruncondition shouldbeunit

=cut

use FindBin::libs;
use Readonly;

use Data::Dump qw/pp/;
use IO::File;

use Test::XTracker::RunCondition export => qw( $distribution_centre );
use Test::XT::Prove::Feature::NominatedDay;
use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local         qw( :DEFAULT );
use XTracker::Constants           qw( :application );
use XTracker::Constants::FromDB   qw(
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_type
                                        :authorisation_level
                                    );

use XTracker::Script::Shipment::NominatedDayPossibleBreach;
use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Flow;
use Test::XT::Data::Container;
use XTracker::EmailFunctions;

Readonly my $TEST_EMAIL_FILE => 't/tmp/test_email.txt';

{
    # FIXME: If this gets ported to Test::Class - make sure we localise this
    # override!
    # monkey patch send_email to write to a file for the purpose of testing
    no strict 'refs'; ## no critic (ProhibitNoStrict)
    no warnings "redefine";
    *XTracker::EmailFunctions::send_email = sub {
        my($from,$replyto,$to,$subject,$msg,$type,$attachments) = @_;

        my $suffix = 1;
        while (-f "${TEST_EMAIL_FILE}.${suffix}") {
            $suffix++;
        }

        my $fh = IO::File->new("> ${TEST_EMAIL_FILE}.${suffix}");
        print $fh $msg;
        $fh->close;
    };
}

my $schema = Test::XTracker::Data->get_schema;

# DC3 carriers only setup for nap (04/12/2012)
my $pid_set = Test::XTracker::Data->get_pid_set(
    $distribution_centre eq 'DC3'
  ? { nap => 1 }
  : { map { $_ => 1 } qw/nap out mrp jc/ }
);


foreach my $bus (values %{$pid_set}) {
    my $channel = $bus->{channel};
    my $pids    = $bus->{pids};

    my $order = create_order($channel,$pids);
    my $shipment = $order->shipments->first;

    note "  SHIPMENTID ". $shipment->id;
    test_nominated_day_possible_and_actual_breach(
        $shipment, $channel->timezone);
}


sub test_nominated_day_possible_and_actual_breach {
    my($shipment, $timezone) = @_;

    my $nom_feature = Test::XT::Prove::Feature::NominatedDay->new();
    foreach my $case (@{$nom_feature->get_nominated_day_test_data}) {

        $nom_feature->set_nominated_fields($shipment, $case, $timezone);
        subtest "test name: $case->{_name}" => sub {
            note "shipment_id ". $shipment->id;

            $nom_feature->test_possible_and_actual_breach(
                $case->{test},
                $shipment,
                $TEST_EMAIL_FILE,
            );
        };
    }
}


sub create_order {
    my($channel,$pids) = @_;

    my $customer    = Test::XTracker::Data->find_customer({
        channel_id => $channel->id,
    });

    Test::XTracker::Data->ensure_stock(
        $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id
    );

    # DC default
    my $shipping_account = Test::XTracker::Data->get_shipping_account( $channel->id );

    my $address = Test::XTracker::Data->create_order_address_in(
        'current_dc',
    );

    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        base => {
            customer_id          => $customer->id,
            channel_id           => $channel->id,
            shipment_type        => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status      => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id  => $shipping_account->id,
            invoice_address_id   => $address->id,
            shipping_charge_id   => 4,   # UK Express
        },
        pids => $pids,
        attrs => [
            { price => 100.00 },
        ],
    });

    return $order;
}

done_testing;
