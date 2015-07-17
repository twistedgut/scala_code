#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Mechanize;
use Data::Dumper;
use XTracker::Database::Finance         qw( :DEFAULT get_credit_hold_thresholds );
use XTracker::Database::Currency        qw( get_local_conversion_rate );
use XTracker::Database::Order           qw( get_order_flags get_order_id );
use XTracker::Database::Customer        qw( :DEFAULT match_customer );
use XTracker::Config::Local             qw( config_var );

use String::Random;

use Data::Dump 'pp';


use XTracker::Database qw( :common );
use XTracker::Constants::FromDB qw( :channel :currency );

# this gives us XT::Domain::Payment with our injected method
use Test::XTracker::Mock::PSP;
use Test::XTracker::Mock::DHL::XMLRequest;

# delete all existing xml files in case of previously crashed test:
Test::XTracker::Data::Order->purge_order_directories;

my $schema  = Test::XTracker::Data->get_schema;
my $dbh     = $schema->storage->dbh;

=head1 NAME

t/20-units/orders/fraud-checks/order_credit_hold.t

=head1 DESCRIPTION

For each currency:

=over

=item create an order less than the Weekly Order Value -- make it's ok.

=item create an order greater than the Weekly Order Value -- make sure it's not ok.

=item create an order less than the Single Order Value - make sure it's ok

=item create an order greater than the Single Order Value -- make sure it's not ok.

=item create a new customer and an order less than the total order value - make sure it's ok.

=item change the date to > 6 months ago

=item add another order to push it over the total order val - this should be ok

=item create a new customer and an order less than the total order value - make sure it's ok.

=item change the date to < 6 months ago

=item add another order to push it over the total order val - and make sure it's not ok.

=back

=cut

my $PIDS = Test::XTracker::Data->get_pid_set({
                nap => 1,
                outnet => 1,
                mrp => 1,
            });


my $rh_test_currencies = {
    GBP => $CURRENCY__GBP,
    USD => $CURRENCY__USD,
    EUR => $CURRENCY__EUR,
};

my @channels = $schema->resultset('Public::Channel')->fulfilment_only( 0 )->enabled;

foreach my $channel ( @channels ) {
    my $channel_id = $channel->id;


    # Find out the limits
    note "Testing for ". $channel->name;
    my $rh_credit_hold_threshholds = get_credit_hold_thresholds($dbh)->{$channel_id};

    note( Dumper $rh_credit_hold_threshholds );

    my ($forget,$pids)  = Test::XTracker::Data->grab_products({
        how_many => 1,
        dont_ensure_stock => 1,
        channel => $channel,
    });
    my $sku = $pids->[0]{sku};


    foreach my $currency (keys(%$rh_test_currencies)) {
        my $conversion_rate = get_local_conversion_rate($dbh, $rh_test_currencies->{$currency});
        note ("Testing with currency $currency - Conversion Rate $conversion_rate ");
        ##
        ## Single order value
        ##
        {
            note ("Testing Single Order Value");
            # use 'matchable' customer as we are only worried about one order
            my $customer_id = Test::XTracker::Data->create_test_customer(
                channel_id => $channel_id,
            );
            note ('Single order value limit GBP = '.
                    $rh_credit_hold_threshholds->{'Single Order Value'});
            my $unit_price = $rh_credit_hold_threshholds->{'Single Order Value'}/
                $conversion_rate - 100;
            my $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);

            note ("Order Id = $order_id");
            my $flags = get_order_flags($dbh, $order_id);
           ok(! flags_contain($flags, 'High Value'),
                'does not exceed the single order value in ' . $currency );

            $customer_id = Test::XTracker::Data->create_test_customer(
                channel_id => $channel_id,
            );
            # exceed single order value
            $unit_price = $rh_credit_hold_threshholds->{'Single Order Value'}/
                $conversion_rate + 100;

            $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);
            $flags = get_order_flags($dbh, $order_id);
            note ('flags = '.Dumper($flags));
            ok(flags_contain($flags, 'High Value'),
                'does exceed the single order value in ' . $currency );
        }

        ##
        ## Weekly order value
        ##
        {
            note ("Testing Weekly Order Value");
            # Create a customer who doesn't look like any other customer
            my $customer_id = create_unmatchable_customer($channel_id);

            # first order under the threshhold
            my $unit_price = $rh_credit_hold_threshholds->{'Weekly Order Value'}/
                $conversion_rate - 200;
            my $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);
            my $flags = get_order_flags($dbh, $order_id);
            note ('flags = '.Dumper($flags));
            ok(!flags_contain($flags, 'Weekly Order Value Limit'),
                'does not exceed the weekly order value in ' . $currency );

            # push order over the threshhold
            $unit_price = 201;
            $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);
            $flags = get_order_flags($dbh, $order_id);
            note ('flags = '.Dumper($flags));
            ok(flags_contain($flags, 'Weekly Order Value Limit'),
                'does exceed the weekly order value in ' . $currency);
        }

        ##
        ## TODO: Test Total Order Value  (EN-554 - point 5)
        ##

        # this is to pull the value for the last 6 months
        # need 2 tests:
        # one with order older than 6 months plus new order
        # one with order inside 6 months plus new order

        # Test with limit order just outside 6 months
        {

            note ("Testing Total Order Value - previous order > 6 months - should not flag");
            # Create a customer who doesn't look like any other customer
            # Create a customer who doesn't look like any other customer
            my $customer_id = create_unmatchable_customer($channel_id);
            # first order under the threshhold
            my $unit_price = $rh_credit_hold_threshholds->{'Total Order Value'}/
                $conversion_rate - 500; # tax is higher so need more margin?
            my $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);

            my $flags = get_order_flags($dbh, $order_id);
            note ('flags = '.Dumper($flags));
            ok(!flags_contain($flags, 'Total Order Value Limit'),
                'First order does not exceed the total order value in ' . $currency );

            # fudge order date to just outside 6 months
            my $order = $schema->resultset('Public::Orders')->find($order_id);
            $order->date( $order->date->add( months => -6, end_of_month => 'limit')->add( days => -5) );
            note("Fudging order date to just over 6 months ago: " . $order->date);
            $order->update;

            # push order over the threshhold
            $unit_price = 505;
            $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);
            $flags = get_order_flags($dbh, $order_id);
            note ('flags = '.Dumper($flags));
            ok(!flags_contain($flags, 'Total Order Value Limit'),
                'Second order (previous order outside 6 months) does not exceed the total order value in ' . $currency );
        }

        # Test with limit order just inside 6 months
        {
            note ("Testing Total Order Value - previous order < 6 months - should flag");
            # Create a customer who doesn't look like any other customer
            my $customer_id = create_unmatchable_customer($channel_id);

            # first order under the threshhold
            my $unit_price = $rh_credit_hold_threshholds->{'Total Order Value'}/
                $conversion_rate - 500;
            my $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);

            my $flags = get_order_flags($dbh, $order_id);
            note ('flags = '.Dumper($flags));
            ok(!flags_contain($flags, 'Total Order Value Limit'),
                'First order does not exceed the total order value' );

            # fudge order date to just within 6 months
            my $order = $schema->resultset('Public::Orders')->find($order_id);
            $order->date( $order->date->add( months => -6, end_of_month => 'limit')->add(days => 5) );
            note("Fudging order date to just less than 6 months ago: " . $order->date);
            $order->update;

            # push order over the threshhold
            $unit_price = 505;
            $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);

            $flags = get_order_flags($dbh, $order_id);
            note ('flags = '.Dumper($flags));
            ok(flags_contain($flags, 'Total Order Value Limit'),
                'Second order (previous order inside 6 months) exceeds total order value in ' . $currency);
        }

        # Test cancelled order should not credit hold
        {
            note ("Testing cancelled order - should not flag");
            # Create a customer who doesn't look like any other customer
            my $customer_id = create_unmatchable_customer($channel_id);
            # first order under the threshhold
            my $unit_price = 500;
            my $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);
            my $order = $schema->resultset('Public::Orders')->find($order_id);
            $order->order_status_id( 4 );
            note("Cancelling order");
            $order->update;

            # push order over the threshhold
            $unit_price = 500;
            $order_id = create_and_import_order($unit_price, $customer_id, $currency, $channel, $sku);

            my $flags = get_order_flags($dbh, $order_id);
            note ('flags = '.Dumper($flags));
            ok(!flags_contain($flags, 'Has Cancelled Orders'),
                'Previous cancelled order does not flag');
        }

    }
}

done_testing;

sub create_unmatchable_customer {
    my ($channel_id) = @_;

    my $i = 0;
    my $rstring  = String::Random->new(max => 15);

    my $customer_id;
    do {
        if ($i > 10) {
            ok (0,'Failed to create an unmatchable customer');
            plan skip_all => 'must rewrite create_unmatchable_customer';
        }
        $i++;
        my $email = $rstring->randregex('\w\w\w\w\w\w\w\w\w\w\w').'@gmail.com';
        note("Random email $email");
        $customer_id = Test::XTracker::Data->create_test_customer(
            channel_id => $channel_id, email => $email);
    } until  scalar(@{match_customer ($dbh, $customer_id) }) == 0;

    return $customer_id;
}

sub create_and_import_order {
    my ($unit_price, $customer_id, $currency, $channel, $sku) = @_;

    my $customer    = $schema->resultset('Public::Customer')->find( $customer_id );

    my $order_args = [
            {
                customer    => {
                    id => $customer->is_customer_number,
                    email => $customer->email,
                    currency => $currency,
                },
                order       => {
                    channel_prefix => $channel->business->config_section,
                    tender_type => 'Card',
                    pre_auth_code => Test::XTracker::Data->get_next_preauth( $dbh ),
                    shipping_price => 0,
                    shipping_tax => 0,
                    shipping_duties => 0,
                    # amount plus standard shipping costs which are in the XML Template
                    tender_amount => $unit_price + 10.00 + 2.00,
                    items   => [
                        {
                            #sku         => $PIDS->{nap}{pids}[0]{sku},
                            sku         => $sku,
                            unit_price  => $unit_price,
                            tax         => 10.00,
                            duty        => 2.00,
                        },
                    ],
                },
            },
        ];

    note Dumper($order_args);
    # parse an order
    my $parsed      = Test::XTracker::Data::Order->create_order_xml_and_parse($order_args);
    my $data_order  = $parsed->[0];

    # part digest the parsed order
    my $order   = $data_order->digest;

    $order->discard_changes;
    note "Price: " . ( $unit_price + 10.00 + 2.00 );
    note "Order Value: " . $order->total_value;
    note "Order_number = ".$order->order_nr." , order_id = ".$order->id;

    return $order->id;
}

sub flags_contain {
    my ($flags, $description) = @_;

    foreach my $order_flag_id (keys(%$flags)) {
        return 1 if $flags->{$order_flag_id}->{description} eq $description;
    }

    return;
}

