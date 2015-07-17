#!/usr/bin/env perl

=head1 NAME

customer_value.t - Get Customer Value for Display on Customer View page

=head1 DESCRIPTION

This tests the call that the AJAX request uses on the Customer View page to get the 'Customer Value' for a Customer.

This will tests using the URL: /customercare/customer/customer_value which is being served by the XT Catalyst App.
using the 'XT::DC::Controller::CustomerCare::Customer' controller.

Also tests the Customer View page it'self (/CustomerCare/CustomerSearch/CustomerView) to make sure the 'Customer Value'
table appears on the page.

#TAGS customerview cando

=cut

use NAP::policy "tt", 'test';

use DateTime;
use DateTime::Duration;
use JSON;
use Data::Dump  qw( pp );

use Test::XTracker::Data;
use Test::XT::DC::Mechanize;
use Test::XT::Flow;

use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :currency
                                        );
use XTracker::Config::Local qw( config_var );

use XT::Net::Seaview::TestUserAgent;

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

#--------- Tests ----------------------------
_test_customer_view_page( $schema, 1 );
_test_ajax_service( $schema, 1 );
#--------------------------------------------

done_testing;

#-----------------------------------------------------------------

=head1 METHODS

=head2 _get_dbl_submit_token

    $dbl_submit_token = _get_dbl_submit_token( $mech_object );

Helper to return a Double Submit token used in the AJAX call.

=cut

sub _get_dbl_submit_token {
    my $mech = shift;

    my $dbl_submit_token = XTracker::DblSubmitToken->generate_new_dbl_submit_token(
        $schema,
    );

    note "returning $dbl_submit_token";
    return $dbl_submit_token;

}

=head2 _test_customer_view_page

    _test_customer_view_page( $schema, $ok_to_do_flag );

This just tests to make sure the 'Customer Value' heading is on the 'Customer View' page.

=cut

sub _test_customer_view_page {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_customer_view_page", 1    if ( !$oktodo );

        note "TESTING Customer View Page";

        my $framework   = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::CustomerCare',
                'Test::XT::Data::Channel',
                'Test::XT::Data::Customer',
            ],
        );

        my $customer    = $framework->customer;
        my $order       = _create_test_order( $customer );

        # set the Sales Channel for NaP
        $framework->mech->channel( $customer->channel );

        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                ]
            }
        } );

        $framework->flow_mech__customercare__customerview( $customer->id );

        my $page_data   = $framework->mech->as_data;
        ok( exists( $page_data->{page_data}{customer_value} ), "'Customer Value' table exists in page" );
    };
}

=head2 _test_ajax_service

    _test_ajax_service( $schema, $ok_to_do_flag );

This tests the call to the AJAX Service and that the Value returned is sane.

Tests where Customer's are in different Sales Channels but still returns Values
for each Sales Channel.

Also tests passing no or wrong customer id to the service.

=cut

sub _test_ajax_service {
    my ( $schema, $oktodo )     = @_;

    my $dbh = $schema->storage->dbh;

    SKIP: {
        skip "_test_ajax_service", 1    if ( !$oktodo );

        note "TESTING AJAX Service";

        my $json    = JSON->new();
        my $mech    = Test::XT::DC::Mechanize->new;

        Test::XTracker::Data->grant_permissions( 'it.god', 'Customer Care', 'Customer Search', $AUTHORISATION_LEVEL__OPERATOR );
        $mech->login_ok;

        my %cust_value;
        my @channels    = $schema->resultset('Public::Channel')
                                    ->channel_list
                                        ->search( {}, { order_by => 'me.id' } );

        # email address to be used by all customers so
        # that they can be thought of as the same customer
        # on different Sales Channels
        my $common_email    = "";

        my $counter = 0;

        # create a Customer for each Sales Channel and then
        # see that we get back Customer Values for each
        # channel in the request to the web-site
        foreach my $channel ( @channels ) {
            note "Sales Channel: (" . $channel->id . ") " . $channel->name;
            my $dataset = Test::XT::Flow->new_with_traits(
                traits => [
                    'Test::XT::Data::Channel',
                    'Test::XT::Data::Customer',
                ],
            );

            $schema->txn_begin;

            my $channel = $dataset->channel( $channel );   # set the channel
            my $customer= $dataset->customer;
            if ( $common_email eq "" ) {
                # first time run through change
                # the email to be unique
                $common_email   = $customer->id . "." . $customer->email;
            }
            # update the email address to be
            # the same as all the others
            $customer->update( { email => $common_email } );

            my $order   = _create_test_order( $customer );

            # get the customer value ourselves then compare it with what comes back from the request
            my $tmp = $customer->calculate_customer_value;
            %cust_value = ( %cust_value, %{ $tmp } );

            $schema->resultset('SystemConfig::ConfigGroup')
                ->find( {
                    name        => 'SendToBOSH',
                    channel_id  => undef } )
                ->find_related( config_group_settings => {
                    setting => 'Customer Value' } )
                ->update( {
                    value => 'On' } );

            # Clear the method call history and inject a single OK response.
            XT::Net::Seaview::TestUserAgent->clear_last_customer_bosh_PUT_request;
            XT::Net::Seaview::TestUserAgent->add_to_response_queue( customer_bosh_PUT => 200 );

            $mech->post_ok( "/customercare/customer/customer_value", {
                customer_id => $customer->id,
                dbl_submit_token => _get_dbl_submit_token($mech),
                format => 'json'
            });

            # Check the customer_bosh_PUT method got called with the right parameters.
            my $channel_name  = $customer->channel->web_name;
            my $currency_name = $order->currency->currency;
            my $account_urn   = $customer->account_urn;
            $account_urn      =~ s/\Aurn:nap:account:(.+)\Z/$1/;

            my $bosh_key = 'customer_value_'
              . config_var('DistributionCentre', 'name');

            my $last_bosh_PUT_request
              = XT::Net::Seaview::TestUserAgent->get_last_customer_bosh_PUT_request;

            my $parsed_content = decode_json($last_bosh_PUT_request->[0]->content);

            my $customer_value_cmp = {
                'channel'     => $channel_name,
                'total_spend' => [
                    {   'spend_currency' => $currency_name,
                        'spend'          => re('\d+')
                    }
                ]
            };

            cmp_deeply( $parsed_content, $customer_value_cmp,
                        'Bosh PUT request content looks correct' );

            cmp_deeply( $last_bosh_PUT_request, [
                # Should be an HTTP::Request object.
                methods(
                    uri     => methods(
                        as_string => re( qr|/bosh/account/$account_urn/$bosh_key| ),
                    ),
                ),
                {
                    urn => $account_urn,
                    key => $bosh_key,
                } ],
                'The last call to customer_bosh_PUT was correct' );

            my $retdata = eval { $json->decode( $mech->content ) } || diag $@ . "\n" . $mech->content;
            note $retdata;
            isa_ok( $retdata, 'HASH', "Data returned is a HASH" );
            is_deeply( $retdata, \%cust_value, "Data came back as expected, for customer records across " . ++$counter . " sales channels" );

            $schema->txn_rollback;

        }

        note "test passing no or wrong customer id to service";
        foreach my $cust_id ( -1, 'fred', 'empty', undef ) {
            my $params  = {};

            if ( !defined $cust_id || $cust_id ne 'empty' ) {
                note "using Customer Id: " . ( defined $cust_id ? $cust_id : 'undef' );
                $params->{customer_id}  = $cust_id;
            }
            else {
                note "not passing the 'customer_id' parameter in the request";
            }

            $params->{dbl_submit_token} = _get_dbl_submit_token($mech->clone());
            $params->{format} = 'json';

            $mech->post_ok( "/customercare/customer/customer_value", $params );
            my $tmp = eval { $json->decode( $mech->content ) } || diag $@ . "\n" . $mech->content;
            ok( exists( $tmp->{error} ), "Got 'error' key back" );
            like( $tmp->{error}, qr/Couldn't find a Customer Record/, "Found appropriate error message" );
        }
    };
}

#-----------------------------------------------------------------

=head2 _create_test_order

    $dbic_order = _create_test_order( $dbic_customer );

Helper to create a test order.

=cut

sub _create_test_order {
    my ( $customer )    = @_;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
            how_many    => 1,
            channel     => $customer->channel,
            dont_ensure_stock => 1,
    } );

    my $base    = {
            customer_id => $customer->id,
            date => (   # set date to be in the 12 month period from yesterday backwards
                        DateTime->now( time_zone => 'local' )
                            - DateTime::Duration->new( days => 5 )
                    ),
            shipping_charge => 10,
            create_renumerations => 1,
            currency_id => $CURRENCY__GBP,
            channel_id => $channel->id,
        };

    my ( $order, $order_hash )  = Test::XTracker::Data->create_db_order( {
            pids => $pids,
            base => $base,
            # adjust the unit price using the channel id so don't get the same total all the time
            attrs => [ { price => ( $channel->id * 100 ), tax => 0, duty => 0 } ],
        } );

    ok($order, 'created order Id/Nr: '.$order->id.'/'.$order->order_nr.', Date: '.$order->date );

    # create renumeration items
    my $shipment    = $order->get_standard_class_shipment;
    my $renumeration= $shipment->renumerations->first;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'me.id' } )->all;
    foreach my $si ( @ship_items ) {
        $si->create_related( 'renumeration_items', {
                                        unit_price  => $si->unit_price,
                                        tax         => $si->tax,
                                        duty        => $si->duty,
                                        renumeration_id => $renumeration->id,
                                } );
    }

    return $order;
}

