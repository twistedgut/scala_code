#!/usr/bin/env perl

=head1 NAME

inthebox_packer_message.t - Orders which should be Assigned InTheBox Marketing Promotions

=head1 DESCRIPTION

This tests that when and Order should be assigned to a Marketing Promotion that
it is and that the Packers Message is displayed on the Pack Shipment page.

=head2 Test cases

    * Designer: Order Associated with NO Promotions, Should See NO Messages
    * Designer: Order Associated with One Promotion, Should See One Message
    * Designer: Order Associated with more than One Promotion, Should See more than One Message
    * Customer with Designer: Promotion With Customer and Designer
    * Customer: Customer Associated with Promotion but without designer
    * Customer With Designer: customer segment without customer
    * Enabled Promotion with NO Associations just with a Date Range, Should See Packers Message

Originally done for CANDO-880, CANDO-1322

#TAGS fulfilment packing promotion loops checkruncondition whm

=cut

use NAP::policy "tt",     'test';

use DateTime;

use Test::XTracker::Data;
use Test::XTracker::RunCondition
    export => [ qw( $distribution_centre ) ];

use Test::XTracker::Data::MarketingPromotion;
use Test::XTracker::Data::MarketingCustomerSegment;
use Test::XTracker::Data::Designer;
use Test::XT::Flow;
use Test::XT::Data::Container;

use XTracker::Config::Local             qw( sys_config_groups config_var );
use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                        );
use XTracker::DHL::RoutingRequest qw( set_dhl_destination_code );


my $channel     = Test::XTracker::Data->channel_for_nap();
# disable all Current Promotions for the Sales Channel
my @enabled_promotions  = $channel->marketing_promotions
                                    ->search( { enabled => 1 } )
                                        ->all;
_toggle_promotions( \@enabled_promotions, 0 );


my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);

$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [ 'Fulfilment/Packing' ]},
    dept => 'Customer Care'
});

$framework->mech__fulfilment__set_packing_station( $channel->id );

my @designers               = Test::XTracker::Data::Designer->grab_designers( { how_many => 6 } );
my $designer_not_in_promo   = shift @designers;     # have one Designer that won't end up in a Promotion

my $date_to_use = DateTime->now();
my %tests   = (
        "Designer: Order Associated with NO Promotions, Should See NO Messages"   => {
                num_promos      => 1,
                use_designers   => [ $designers[0] ],
                dont_update_pid_designer => 1,
                expect_to_see_promos  => undef,
            },
        "Designer: Order Associated with One Promotion, Should See One Message"   => {
                num_promos      => 1,
                use_designers   => [ $designers[0] ],
                expect_to_see_promos  => [ 1 ],
            },
        "Designer: Order Associated with more than One Promotion, Should See more than One Message"   => {
                num_promos      => 3,
                use_designers   => [ @designers[0..2] ],
                expect_to_see_promos  => [ 1..3 ],
           },
        "Customer with Designer: Promotion With Customer and Designer" => {
                num_promos      => 1,
                use_designers   => [ $designers[0] ],
                use_customer_segment => 1,
                expect_to_see_promos  => [ 1 ],
        },
        "Customer: Customer Associated with Promotion but without designer" =>{
                num_promos      => 1,
                use_customer_segment => 1,
                use_designers   => [ ],
                expect_to_see_promos  => [ 1 ],
        },
        "Customer With Designer: customer segment without customer" =>{
                num_promos      => 1,
                use_designers   => [ $designers[0] ],
                customer_segment_without_customer => 1,
                expect_to_see_promos  => undef,
        },
        "Enabled Promotion with NO Associations just with a Date Range, Should See Packers Message" => {
                num_promos      => 1,
                use_designers   => [],
                expect_to_see_promos => [ 1 ],
            },
    );

foreach my $label ( keys %tests ) {
    note "TESTING: ${label}";
    my $test    = $tests{ $label };

    my $num_promos  = $test->{num_promos};
    my @designers   = @{ $test->{use_designers} };

    my @expected_promos;
    my @promotions;

    # create an Order
    my $order_dets  = _create_an_order( $channel, 5, $designer_not_in_promo );
    my $tote_id     = $order_dets->{tote_id};
    my $order       = $order_dets->{order_object};
    my $shipment    = $order_dets->{shipment_object};
    my @ship_items  = $shipment->shipment_items->all;
    my $customer = $order->customer;

    if ( config_var('DHL', 'xmlpi_region_code') eq 'AM' )  {
        my $dbh = $framework->schema->storage->dbh;
        fail('Remove obsolete block of code that fixes previous test failure')
            if ( $shipment->destination_code && $shipment->is_carrier_automated );
        set_dhl_destination_code( $dbh, $shipment->id, 'LHR' );
        $shipment->set_carrier_automated( 1 );
        is( $shipment->is_carrier_automated, 1, "Shipment is now Automated" );
    }

    # create Promotions for the Test
    foreach my $num ( 1..$num_promos ) {
        my $promotion   = Test::XTracker::Data::MarketingPromotion->create_marketing_promotion( {
                                                title       => "TEST Promotion Title " . $num,
                                                channel_id  => $channel->id,
                                                start_date  => $date_to_use->clone->subtract( days => 1 ),
                                                end_date    => $date_to_use->clone->add( days => 1 ),
                                                message     => "Instruction to Packer to Put in Marketing Paper: " . $num,
                                        } )->[0];
        if ( @designers ) {
            my $designer    = shift @designers;
            $promotion->create_related( 'link_marketing_promotion__designers', {
                                                    designer_id => $designer->{designer_id},
                                                    include     => 1,
                                            } );
            push @designers, $designer;
        }

        if($test->{use_customer_segment}) {

            my $customer_segment = Test::XTracker::Data::MarketingCustomerSegment->create_customer_segment ({
                channel_id => $channel->id,
            });

            #link marketing promotion to customer segement
            $promotion->create_related( 'link_marketing_promotion__customer_segments',{
                customer_segment_id => @$customer_segment[0]->id,
            });

            #add customer id to customer segment
            Test::XTracker::Data::MarketingCustomerSegment->link_to_customer(
                @$customer_segment[0],
                $customer,
            );
        }

        if( $test->{customer_segment_without_customer} ) {

            my $customer_segment = Test::XTracker::Data::MarketingCustomerSegment->create_customer_segment ({
                channel_id => $channel->id,
            });
            $promotion->create_related( 'link_marketing_promotion__customer_segments',{
                customer_segment_id => @$customer_segment[0]->id,
            });
        }

        push @promotions, $promotion;

        if ( $test->{expect_to_see_promos} ) {
            # if the test is expecting to see any Promotions
            # and this number Promotion is one expected to see
            push @expected_promos, $promotion
                            if ( grep { $_ == $num } @{ $test->{expect_to_see_promos} } );
        }
    }


    # if there are any Designers for the test
    # then set some of the Products to be for them
    if ( !$test->{dont_update_pid_designer} ) {
        foreach my $idx ( 0..$#designers ) {
            _update_item_designer( $ship_items[ $idx ], $designers[ $idx ] );
        }
    }

    # start Packing
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $tote_id )
        ->flow_mech__fulfilment__packing_checkshipment_submit();


    # check the Marketing Promotions Packer Messages can be seen
    # and the Order is associated with the Promotions at a DB level
    $order->discard_changes;
    my %expected    = map { $_->id => $_->message } @expected_promos;
    my $messages    = $framework->mech->as_data()->{packer_messages}{marketing_promotion} // {};
    is_deeply( $messages, \%expected, "Can See All Expected Packer Messages on 'Pack Shipment' page (" . @expected_promos . " promos)" );
    is_deeply(
                [
                    map { $_->marketing_promotion_id }
                        $order->link_orders__marketing_promotions
                                ->search( {}, { order_by => 'marketing_promotion_id' } )
                                    ->all
                ],
                [
                    sort { $a <=> $b }
                        map { $_->id } @expected_promos
                ],
                "and All Expected Marketing Promotions are Associated with the Order at a DB level"
            );


    foreach my $item ( @ship_items ) {
        $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $item->get_sku );
    }

    # Submit box id's plus a container id
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            channel_id => $channel->id,
            tote_id    => Test::XT::Data::Container->get_unique_id(),
        );

    # submit waybill if expect_AWB is set in config
    $framework->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789") if config_var('DistributionCentre','expect_AWB');

    $framework->flow_mech__fulfilment__packing_packshipment_complete;

    # remove test data
    foreach my $promotion ( @promotions ) {
        $promotion->discard_changes->link_marketing_promotion__designers->delete;
        $promotion->discard_changes->link_marketing_promotion__customer_segments->delete;
        $promotion->link_orders__marketing_promotions->delete;
        $promotion->delete;
    }
}

# restore Promotions Enabled state
_toggle_promotions( \@enabled_promotions, 1 );

done_testing;


#---------------------------------------------------------------------------------------------------------

sub _toggle_promotions {
    my ( $promotions, $state )  = @_;

    foreach my $promotion ( @{ $promotions } ) {
        $promotion->discard_changes->update( { enabled => $state } );
    }

    return;
}

sub _create_an_order {
    my ( $channel, $num_prods, $designer )  = @_;

    my $order_dets  = $framework->flow_db__fulfilment__create_order_picked( channel => $channel, products => $num_prods );
    my @ship_items  = $order_dets->{shipment_object}->shipment_items->all;

    # set all Product's Designer to be the for $designer
    foreach my $item ( @ship_items ) {
        _update_item_designer( $item, $designer );
    }

    note "Order Id/Nr: " . $order_dets->{order_object}->id . "/" . $order_dets->{order_object}->order_nr;
    note "Shipment Id: " . $order_dets->{shipment_object}->id;

    return $order_dets;
}

sub _update_item_designer {
    my ( $item, $designer )     = @_;

    $item->variant
            ->product
                ->update( { designer_id => $designer->{designer_id} } );

    return;
}
