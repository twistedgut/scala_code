#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-326: Outnet Canvas Bag promotion

This will test the '<GIFT_LINE>' tag applies a Free Promotional Gift to the Order when present and that if Opted Out it won't.

This is not just for 'THE OUTNET tote' Free Gift Item.

=cut


use Test::Exception;
use Test::XTracker::Hacks::TxnGuardRollback;
use Test::XTracker::Data;
use Test::XTracker::Data::Order;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :note_type
                                        :promotion_class
                                    );

use Data::Dump  qw( pp );

use Test::XT::Data;


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );
my $dbh = $schema->storage->dbh;

note "Check 'THE OUTNET tote' Promotion Type is in the Database";
my $outnet_chn  = Test::XTracker::Data->channel_for_out;
my $pt  = $outnet_chn->promotion_types->search( { name => 'THE OUTNET tote' } )->first;
isa_ok( $pt, 'XTracker::Schema::Result::Public::PromotionType', "Found the Promotion Type in the DB" );


note "Now Test All our Sales Channels can Handle the Gift Line";
# get all NAP Channels
my @channels    = $schema->resultset('Public::Channel')->enabled;

foreach my $channel ( @channels ) {
    note "Testing for Sales Channel: ".$channel->id." - ".$channel->name;

    $schema->txn_do( sub {
        my $data = Test::XT::Data->new_with_traits(
            traits => [
                'Test::XT::Data::Channel',      # defaults to NaP unless otherwise set
                'Test::XT::Data::Customer',
            ],
        );
        $data->channel( $channel );

        # get some products so the they don't have to be got for each order
        my ( $forget, $pids )   = Test::XTracker::Data->grab_products( {
                                             how_many => 1,
                                             channel => $channel,
                                       } );
        # set-up the args for the line item to be used for all of the orders
        my $item_args   = [
                            {
                                sku => $pids->[0]{sku},
                                description => $pids->[0]{product}
                                                        ->product_attribute
                                                            ->name,
                                unit_price => 691.30,
                                tax => 48.39,
                                duty => 0.00
                            },
                        ];

        my $customer= $data->customer;
        # change the Customer Email to be unique, makes the test a bit faster
        $customer->update( { email => $customer->is_customer_number . '.test@net-a-porter.com' } );

        # create Free Gift Promotion Types to be used in the Gift Line
        my @promo_types;
        push @promo_types, Test::XTracker::Data::Order->create_promotion_type( "Test Promo 1", "Test Promotion 1", $PROMOTION_CLASS__FREE_GIFT, $channel );
        push @promo_types, Test::XTracker::Data::Order->create_promotion_type( "Test Promo 2", "Test Promotion 2", $PROMOTION_CLASS__FREE_GIFT, $channel );
        my $non_existent_sku    = "Test Doesn't Exist $$";

        # set-up the tests
        my %tests   = (
                '2 Gifts Not Opting Out 1 Explictily in XML File'   => [
                            {
                                sku => $promo_types[0]->name,
                                description => $promo_types[0]->product_type,
                                opted_out => 'N',
                                test_promo_id => $promo_types[0]->id,
                            },
                            {
                                sku => $promo_types[1]->name,
                                description => $promo_types[1]->product_type,
                                test_promo_id => $promo_types[1]->id,
                            },
                    ],
                '1 Gift Line with the SKU all in Uppercase' => [
                            {
                                sku => uc( $promo_types[0]->name ),
                                description => $promo_types[0]->product_type,
                                opted_out => 'N',
                                test_promo_id => $promo_types[0]->id,
                            },
                    ],
                '1 Gift Line Opted Out, 1 Opted In' => [
                            {
                                sku => $promo_types[0]->name,
                                test_promo_id => $promo_types[0]->id,
                            },
                            {
                                sku => $promo_types[1]->name,
                                test_promo_id => $promo_types[1]->id,
                                opted_out => 'Y',
                            },
                    ],
                '1 Gift Line Opted Out' => [
                            {
                                sku => $promo_types[0]->name,
                                test_promo_id => $promo_types[0]->id,
                                opted_out => 'Y',
                            },
                    ],
                '1 Gift Line Opted In' => [
                            {
                                sku => $promo_types[0]->name,
                                test_promo_id => $promo_types[0]->id,
                            },
                    ],
            );

        # build up the Order Args first to Import the Orders all at once up-front
        my @order_args;
        foreach my $label ( sort keys %tests ) {
            push @order_args, {
                    customer => { id => $customer->is_customer_number, email => $customer->email },
                    order => {
                        items => $item_args,
                        channel_prefix => $channel->business->config_section,
                        gift_lines => $tests{ $label },
                    },
                };
        }
        # add an Order with a non-existent Promotion Type and the Parser should die when it tries to 'digest' it
        push @order_args, {
                customer => { id => $customer->is_customer_number, email => $customer->email },
                order => {
                    items => $item_args,
                    channel_prefix => $channel->business->config_section,
                    gift_lines => [ { sku => $non_existent_sku } ],
                },
            };

        # Create and Parse all Order Files
        my @data_orders = Test::XTracker::Data::Order->create_order_xml_and_parse(
            \@order_args,
        );

        # now test the orders parsed are as expected
        foreach my $label ( sort keys %tests ) {
            note "TEST: $label";

            my $test        = $tests{ $label };
            my $data_order  = shift @data_orders;       # get the order for the test

            # count what is expected after the Order has been 'digested'
            my @expected_order_promos;
            my @expected_order_notes;
            my @promo_ids;

            cmp_ok( $data_order->number_of_gift_line_items, '==', @{ $test }, "Number of Gift Line Items as Expected: ".@{ $test } );

            foreach my $idx ( 0..$#{ $test } ) {
                my $item    = $data_order->gift_line_items->[ $idx ];
                is( $item->sku, $test->[ $idx ]->{sku}, "Gift Line Item ".($idx+1)." SKU as Expected: ".$test->[ $idx ]->{sku} );
                isa_ok( $item, 'XT::Data::Order::GiftLineItem', "Gift Line Item is of expected Class" );
                my $exp_opted_out   = ( !defined $test->[ $idx ]->{opted_out} || uc( $test->[ $idx ]->{opted_out} ) eq 'N' ? 0 : 1 );
                cmp_ok( $item->opted_out, '==', $exp_opted_out, "Gift Line Item Opted Out Flag as Expected: $exp_opted_out" );

                # set what is expected to be created
                if ( !$exp_opted_out ) {
                    push @expected_order_promos, $test->[ $idx ];
                }
                else {
                    push @expected_order_notes, $test->[ $idx ];
                }
                push @promo_ids, $test->[ $idx ]->{test_promo_id};      # store the 'promotion_type_id' expected
            }

            # process the Data Order
            my $order   = $data_order->digest( { skip => 1 } );

            my @promos  = $order->order_promotions->search( { promotion_type_id => \@promo_ids }, { order_by => 'id' } )->all;
            my @notes   = $order->order_notes->search( { note => { like => 'Opted Out Of Free Gift:%' } }, { order_by => 'id' } )->all;

            cmp_ok( @promos, '==', @expected_order_promos, "Number of 'order_promotion' records created as expected: ".@expected_order_promos );
            cmp_ok( @notes, '==', @expected_order_notes, "Number of 'order_note' records created as expected: ".@expected_order_notes );

            # check the 'order_promotion' records created are correct
            foreach my $exp_promo ( @expected_order_promos ) {
                my $promo   = shift @promos;
                cmp_ok( $promo->promotion_type_id, '==', $exp_promo->{test_promo_id},
                                                            "Order Promotion Created with Expected Promo Type Id: ".$exp_promo->{test_promo_id} );
                cmp_ok( $promo->value, '==', 0, "Order Promotion Value as Expected: 0" );
                is( $promo->code, 'none', "Order Promotion Code as Expected: none" );
            }

            # check the 'order_note' records created are correct
            foreach my $exp_note ( @expected_order_notes ) {
                my $note    = shift @notes;
                my $name    = $exp_note->{sku};
                like( $note->note, qr/$name/i, "Order Note Created has the Correct Promo Name in it: $name" );
                cmp_ok( $note->operator_id, '==', $APPLICATION_OPERATOR_ID, "Order Note Operator is 'Application'" );
                cmp_ok( $note->note_type_id, '==', $NOTE_TYPE__ORDER, "Order Note Type is 'Order'" );
            }
        }

        note "TEST: that the Parser Dies with a non-existent Promotion Type";
        my $data_order  = $data_orders[0];      # the Order we want should be the only one left in the Array
        cmp_ok( $data_order->number_of_gift_line_items, '==', 1, "Number of Gift Line Items as Expected: 1" );
        my $item    = $data_order->gift_line_items->[0];
        is( $item->sku, $non_existent_sku , "Gift Line Item SKU as Expected: $non_existent_sku" );
        cmp_ok( $item->opted_out, '==', 0, "Gift Line Item Opted Out Flag as Expected: 0" );
        dies_ok( sub {
                $data_order->digest( { skip => 1 } );
        }, "Died when tried to Parse" );
        like( $@, qr/Couldn't Find a 'promotion_type' for '$non_existent_sku'/, "Got expected die message" );

        # clean-up promotions from DB
        foreach my $pt ( @promo_types ) {
            $pt->search_related( 'order_promotions' )->delete;
            $pt->delete;
        }

        # rollback changes
        $schema->txn_rollback;
    } );
}

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;

#-----------------------------------------------------------------------------
