#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Mechanize;
use Data::Dumper;
#use XTracker::Database::Finance         qw( :DEFAULT get_credit_hold_thresholds );
#use XTracker::Database::Currency        qw( get_local_conversion_rate );
use XTracker::Database::Order           qw( get_order_flags get_order_id );
use XTracker::Database::Customer        qw( :DEFAULT match_customer );
use XTracker::Config::Local             qw( config_var sys_config_var dc_address );
use String::Random;

use Data::Dump 'pp';
use DateTime;

use XTracker::Database qw( :common );
use XTracker::Constants qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw(
    :order_status
    :flag
    :renumeration_type
    :shipment_status
);

# this gives us XT::Domain::Payment with our injected method
use Test::XTracker::Mock::PSP;
use Test::XTracker::Mock::DHL::XMLRequest;

# delete all existing xml files in case of previously crashed test:
Test::XTracker::Data::Order->purge_order_directories;

my $schema  = Test::XTracker::Data->get_schema;
my $dbh     = $schema->storage->dbh;


my $pids = Test::XTracker::Data->get_pid_set({
                nap => 1,
                outnet => 1,
                mrp => 1,
                jc  => 1,
            });



my @channels = $schema->resultset('Public::Channel')->enabled_channels->all;
my $order_xml_data;

my $expected_card_check_rule = {
                                'with_postive_rating' => {
                                            'MRPORTER.COM'     => 50,
                                            'theOutnet.com'    => 200,
                                            'NET-A-PORTER.COM' => 200,
                                            'JIMMYCHOO.COM'    => 200,
                                          },
                                 'with_zero_rating' => {
                                            'MRPORTER.COM'     => 0,
                                            'theOutnet.com'    => 150,
                                            'NET-A-PORTER.COM' => 150,
                                            'JIMMYCHOO.COM'    => 150,
                                          },
                                 'with_negative_rating' => {
                                            'MRPORTER.COM'     => -1,
                                            'theOutnet.com'    => 149,
                                            'NET-A-PORTER.COM' => 149,
                                            'JIMMYCHOO.COM'    => 149,
                                          },
                                'with_negative_values' => {
                                            'MRPORTER.COM'     => -1,
                                            'theOutnet.com'    => -11,
                                            'NET-A-PORTER.COM' => -11,
                                            'JIMMYCHOO.COM'    => -11,
                                    }

                                };


# DC3 - Delete channel data from expected hash if channel is disabled in DC
my %channel_hash = map {$_->name => '1' } @channels;
foreach my $expected_key ( %{$expected_card_check_rule} ) {
    my $hash = $expected_card_check_rule->{$expected_key};
    foreach my $key ( keys %{$hash})  {
        if(!exists $channel_hash{$key} ) {
            delete($hash->{$key});
        }
    }
}

#------------------------ Tests ---------------------
_test__do_card_checks( $schema, 1 );
#---------------------------------------------------
done_testing;
#--------------------------------------------------

sub _test__do_card_checks {
    my( $schema, $oktodo) = @_;

    SKIP: {
        skip "_test__do_card_check", 1 if (!$oktodo);

        note "TESTING Rating adjustments \n";
        my $got_results = {};

        foreach my $channel ( @channels ) {

            isa_ok( $channel, 'XTracker::Schema::Result::Public::Channel', 'Got Channel Record for: '.$channel->id.' - '.$channel->name );
            my $customer_id = create_unmatchable_customer( $channel->id );
            my $customer = $schema->resultset('Public::Customer')->find( $customer_id );

            my ( undef, $pids )  = Test::XTracker::Data->grab_products({
                                how_many            => 1,
                                dont_ensure_stock   => 1,
                                channel             => $channel,
                            });

            my $sku = $pids->[0]{sku};

            $schema->txn_do( sub {

                #update config to known values
                _update_config_values($channel);

                #set the card to be NOT new
                Test::XTracker::Mock::PSP->set_card_history( [ {'orderNumber' => '4423424'},
                                                               {'orderNumber' => '2322323'},
                                                               {'orderNumber' => '3434343'}
                                                             ] ); # random order number, does not matter
                #create new order
                my $order_data =  create_and_import_order( $customer, $channel, $sku );

                my $rating  = 50;
                my $cust_rs = _get_cust_rs_for_order($schema, $order_data->{'order'});
                $got_results->{'with_postive_rating'}->{$channel->name} = $order_data->{'data_order'}->_do_card_checks($order_data->{'order'}, $rating, $cust_rs, 1);

                $rating  = 0;
                $got_results->{'with_zero_rating'}->{$channel->name} = $order_data->{'data_order'}->_do_card_checks($order_data->{'order'}, $rating, $cust_rs, 1);

                $rating  = -1;
                $got_results->{'with_negative_rating'}->{$channel->name} = $order_data->{'data_order'}->_do_card_checks($order_data->{'order'}, $rating, $cust_rs, 1);

                _update_config_values($channel,-10);#
                #to repopulate the latest config values
                $order_data->{'data_order'}->_fraud_check_rating_adjustment ($order_data->{'data_order'}->_build__fraud_check_rating_adjustment);
                $rating = -1;
                $got_results->{'with_negative_values'}->{$channel->name} = $order_data->{'data_order'}->_do_card_checks($order_data->{'order'}, $rating, $cust_rs, 1);

                $schema->txn_rollback();
            });

        }
        note "TESTING Card Check Rule for Postive Rating Adjustment \n";
        is_deeply($got_results->{'with_postive_rating'}, $expected_card_check_rule->{'with_postive_rating'},'Rating Adjustment for Card Check rule with postive rating');

        note "TESTING Card Check Rule for zero Rating Adjustment \n";
        is_deeply($got_results->{'with_zero_rating'}, $expected_card_check_rule->{'with_zero_rating'},'Rating Adjustment for Card Check rule with Zero rating');

        note "TESTING Card Check Rule for Negative Rating Adjustment \n";
        is_deeply($got_results->{'with_negative_rating'}, $expected_card_check_rule->{'with_negative_rating'},'Rating Adjustment for Card Check rule with Negative rating');

        note "TESTING Card Check Rule for Negative Values Adjustment \n";
        is_deeply($got_results->{'with_negative_values'}, $expected_card_check_rule->{'with_negative_values'},'Rating Adjustment for Card Check rule with Negative rating');

    }

}

sub _update_config_values {
    my ($channel, $value) = @_;

    my $config_params     = $channel->config_group->search( { name => 'FraudCheckRatingAdjustment' } ) ;
    my $card_check_rating = '';
    if($config_params->count > 0) {
        $card_check_rating = $config_params->first->config_group_settings_rs->search( { setting => 'card_check_rating' } )->first;
    }

    #update it to known value
    my $val = $value ? $value : 150;
    $card_check_rating->update( { value => $val } ) if $card_check_rating ne '';
    if( $channel->name =~ /MRPORTER.COM/i ) {
        $card_check_rating->update( { value => '0' } ) if $card_check_rating ne '';
    }
}


sub _get_cust_rs_for_order {
    my ( $schema, $order ) = @_;

    my $customer = $order->customer;
    my $similar_customers = $customer->customers_with_same_email;
    my @cust_ids = $similar_customers->get_column('id')->all;
    unshift(@cust_ids,$customer->id);

    my $cust_rs = $schema->resultset('Public::Customer')->search({
        'me.id' => { 'in' => \@cust_ids },
    });

    return $cust_rs;
}

sub create_and_import_order {
    #my ( $unit_price, $customer, $existing_order, $channel, $sku, $new_address ) = @_;
    my (  $customer, $channel, $sku ) = @_;

    my $next_preauth = Test::XTracker::Data->get_next_preauth( $dbh );
    my $dc_address = dc_address($channel);
    my $country      = $schema->resultset('Public::Country')->find_by_name( $dc_address->{country} );
    my $order_args = [
            {
                customer    => {
                    id              => $customer->is_customer_number,
                    email           => $customer->email,
                    address_line_1  => $dc_address->{addr1},
                    address_line_2  => $dc_address->{addr2},
                    address_line_3  => $dc_address->{addr3},
                    town_city       => $dc_address->{city},
                    county          => '',
                    postcode        => '',
                    country         => $country->code,
                },
                order       => {
                    channel_prefix => $channel->business->config_section,
                    tender_type => 'Card',
                    shipping_price => 0,
                    shipping_tax => 0,
                    shipping_duties => 0,
                    # amount plus standard shipping costs which are in the XML Template
                    tender_amount => 2500,# 10.00 + 2.00,
                    pre_auth_code => $next_preauth,
                    items   => [
                        {
                            sku         => $sku,
                            unit_price  => 2500,
                            tax         => 0.00,
                            duty        => 0.00,
                        },
                    ],
                },
            },
        ];

    note Dumper($order_args);
    # parse an order
    my $parsed = Test::XTracker::Data::Order->create_order_xml_and_parse(
        $order_args,
    );
    my $data_order  = $parsed->[0];

    # part digest the parsed order
    my $order   = $data_order->digest;

    $order->discard_changes;

    $order_xml_data->{'data_order'} = $data_order;
    $order_xml_data->{'order'} = $order;

    return $order_xml_data;
}


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








