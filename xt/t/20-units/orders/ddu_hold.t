#!/usr/bin/env perl

use NAP::policy "tt",         'test';

=head2 Tests for Placing Orders on DDU Hold

This test checks
  * That an Order is placed on DDU Hold
  * That a 'DDU Order - Request accept shipping terms' email is sent to the Customer

=cut

use Test::XTracker::Data;
use Test::XTracker::Hacks::TxnGuardRollback;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::CMS;
use Test::XTracker::Data::FraudRule;
use Test::XT::Data;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants::FromDB     qw(
                                        :correspondence_templates
                                        :country
                                        :flag
                                        :shipment_status
                                        :shipment_type
                                    );


# redefine the '_apply_credit_rating' method
# so that nothing gets put on Finance Hold
no warnings "redefine";
use XT::Data::Order;
*XT::Data::Order::_apply_credit_rating  = sub { ## no critic(ProtectPrivateVars)
    note "========> IN REDEFINED '_apply_credit_rating' METHOD";
    return 1;
};
use warnings "redefine";


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

# set-up a resultset to get back 3 Countries
my $country_rs  = $schema->resultset('Public::Country')
                                    ->search(
                                        {
                                            'me.id'     => { '!=' => $COUNTRY__UNKNOWN },
                                            'me.country'=> { '!=' => config_var("DistributionCentre","country") },
                                        },
                                        {
                                            join => 'country_shipment_types',
                                            rows => 3,
                                        }
                                    );
# set-up a resultset to get get Shipment Email logs
# for the 'DDU Order - Request accept shipping terms'
my $ship_ddu_email_log_rs   = $schema->resultset('Public::ShipmentEmailLog')
                                    ->search(
                                        {
                                            correspondence_templates_id => $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__REQUEST_ACCEPT_SHIPPING_TERMS,
                                        }
                                    );

my @channels    = $schema->resultset('Public::Channel')->enabled_channels->search( { fulfilment_only => 0 }, { join => 'business' } )->all;

$schema->txn_do( sub {
    Test::XTracker::Data::FraudRule->switch_all_channels_off();

    # clear the CMS Id for the Template
    Test::XTracker::Data::CMS->clear_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__REQUEST_ACCEPT_SHIPPING_TERMS );

    foreach my $channel ( @channels ) {
        note "Testing for Sales Channel: " . $channel->name;

        # remove any remaining Order XML Files
        Test::XTracker::Data::Order->purge_order_directories();

        # create 3 Customers and set the 'ddu_terms_accepted' flags
        my @customers   = (
                            Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } ),
                            Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } ),
                            Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } ),
                        );
        # set the second Customer to have accepted DDU Terms for all Orders
        $customers[1]->update( { ddu_terms_accepted => 1 } );

        my ($forget,$pids)  = Test::XTracker::Data->grab_products( {
                    how_many=> 1,
                    channel => $channel,
            } );
        my $product     = $pids->[0];

        # get 3 Countries for this Channel
        my @countries   = $country_rs->search( { 'channel_id' => $channel->id } )->all;
        _remove_shipment_types( $schema, $channel, @countries );
        # set NON Auto DDU Countries
        $countries[0]->create_related( 'country_shipment_types', {
                                                    shipment_type_id=> $SHIPMENT_TYPE__INTERNATIONAL_DDU,
                                                    auto_ddu        => 0,
                                                    channel_id      => $channel->id,
                                            } );
        $countries[1]->create_related( 'country_shipment_types', {
                                                    shipment_type_id=> $SHIPMENT_TYPE__INTERNATIONAL_DDU,
                                                    auto_ddu        => 0,
                                                    channel_id      => $channel->id,
                                            } );
        # set an Auto DDU Country
        $countries[2]->create_related( 'country_shipment_types', {
                                                    shipment_type_id=> $SHIPMENT_TYPE__INTERNATIONAL_DDU,
                                                    auto_ddu        => 1,
                                                    channel_id      => $channel->id,
                                            } );

        # the Order details for each Order can be the same
        my $order_dets  = {
                channel_prefix => $channel->business->config_section,
                tender_amount => 110.00,
                shipping_price => 10,
                shipping_tax => 1.50,
                items => [
                    {
                        sku => $product->{sku},
                        description => $product->{product}
                                                ->product_attribute
                                                    ->name,
                        unit_price => 100,
                        tax => 10,
                        duty => 0,
                    },
                ],
            };

        # Set-up options for the the Order XML file that will be created
        my $order_args  = [
            {   # this Order should go on DDU Hold
                customer => {
                                id      => $customers[0]->is_customer_number,
                                country => $countries[0]->code,
                                email   => 'test1@example.com',
                            },
                order => $order_dets,
            },
            {   # this Order should NOT go on DDU Hold because the Customer has already accepted Terms
                customer => {
                                id      => $customers[1]->is_customer_number,
                                country => $countries[1]->code,
                                email   => 'test2@example.com',
                            },
                order => $order_dets,
            },
        ];
        # Only do this if we have countries with auto_ddu (currently DC3
        # doesn't have any)
        # this Order should NOT go on DDU Hold because it is for a Auto DDU Country
        push @$order_args, {
            customer => {
                            id      => $customers[2]->is_customer_number,
                            country => $countries[2]->code,
                            email   => 'test3@example.com',
                        },
            order => $order_dets,
        } if $countries[2];

        # Create and Parse all Order Files
        my $parsed  = Test::XTracker::Data::Order->create_order_xml_and_parse($order_args);

        my $order;
        my $shipment;

        note "FIRST Order Should be on DDU Hold, because the Customer has NOT Accepted DDU Terms for all Orders";
        isa_ok( $order = $parsed->[0]->digest( { skip => 1 } ), 'XTracker::Schema::Result::Public::Orders', 'Order Digested' );
        $shipment   = $order->get_standard_class_shipment;
        cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DDU_HOLD,
                                    "Shipment Status is 'DDU Hold'" );
        cmp_ok( $shipment->shipment_flags->search( { flag_id => $FLAG__DDU_PENDING } )->count, '==', 1,
                                    "Shipment has a 'DDU PENDING' Flag attached to it" );
        cmp_ok( $ship_ddu_email_log_rs->search( { shipment_id => $shipment->id } )->count, '==', 1,
                                    "Shipment has had a 'DDU Order - Request accept shipping terms' email sent" );


        note "SECOND Order Should NOT be on DDU Hold, because the Customer has Accepted DDU Terms for all Orders";
        isa_ok( $order = $parsed->[1]->digest( { skip => 1 } ), 'XTracker::Schema::Result::Public::Orders', 'Order Digested' );
        $shipment   = $order->get_standard_class_shipment;
        cmp_ok( $shipment->shipment_status_id, '!=', $SHIPMENT_STATUS__DDU_HOLD,
                                    "Shipment Status is NOT 'DDU Hold'" );
        cmp_ok( $shipment->shipment_flags->search( { flag_id => $FLAG__DDU_PENDING } )->count, '==', 0,
                                    "Shipment does NOT have a 'DDU PENDING' Flag attached to it" );
        cmp_ok( $ship_ddu_email_log_rs->search( { shipment_id => $shipment->id } )->count, '==', 0,
                                    "Shipment has NOT had a 'DDU Order - Request accept shipping terms' email sent" );


        SKIP: {
            skip 'no auto ddu countries', 4 unless $countries[2];
            note "THIRD Order Should NOT be on DDU Hold, because the Country is Auto DDU";
            isa_ok( $order = $parsed->[2]->digest( { skip => 1 } ), 'XTracker::Schema::Result::Public::Orders', 'Order Digested' );
            $shipment   = $order->get_standard_class_shipment;
            cmp_ok( $shipment->shipment_status_id, '!=', $SHIPMENT_STATUS__DDU_HOLD,
                                        "Shipment Status is NOT 'DDU Hold'" );
            cmp_ok( $shipment->shipment_flags->search( { flag_id => $FLAG__DDU_PENDING } )->count, '==', 0,
                                        "Shipment does NOT have a 'DDU PENDING' Flag attached to it" );
            cmp_ok( $ship_ddu_email_log_rs->search( { shipment_id => $shipment->id } )->count, '==', 0,
                                        "Shipment has NOT had a 'DDU Order - Request accept shipping terms' email sent" );
        }
    }


    # rollback all changes
    $schema->txn_rollback();
} );

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;

#--------------------------------------------------------------

# delete 'country_shipment_type' records the hard way because
# there isn't a PKEY on the table, not that there needs to be.
sub _remove_shipment_types {
    my ( $schema, $channel, @countries )    = @_;

    my $dbh         = $schema->storage->dbh;
    my @country_ids = map { $_->id } @countries;

    my $sql =<<SQL
DELETE FROM country_shipment_type
WHERE channel_id = ?
AND country_id IN ( ?, ?, ? )
SQL
;
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $channel->id, @country_ids );

    return;
}
