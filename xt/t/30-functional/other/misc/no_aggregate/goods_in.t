#!/usr/bin/env perl

=head1 NAME

goods_in.t - Test Goods In Quality Control process

=head1 DESCRIPTION

Test Goods In Quality Control process.

#TAGS intermittentfailure needswork activemq iws goodsin qualitycontrol stockin checkruncondition

=head1 TODO

Get this back in the aggregated Test::Class tests.

DCA-2344: This test wasn't happy when run on jenkins from the aggregate
test class job (intermittent amq monitor problems).

    # Commented out code:
    #package Test::NAP::GoodsIn;

=cut

use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';

use Test::More::Prefix 'test_prefix';
use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::RunCondition export => '$distribution_centre';

use XTracker::Constants::FromDB qw(
    :authorisation_level
);

sub startup : Test(startup => 1) {
    my ( $self ) = @_;

    test_prefix 'Startup';

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [qw(
            Test::XT::Flow::GoodsIn
            Test::XT::Flow::PrintStation
        )],
    );

    $self->_login_as_department('Distribution');
}

sub _login_as_department {
    my ( $self, $department ) = @_;

    $self->{framework}->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Goods In/Stock In',
                'Goods In/Item Count',
                'Goods In/Quality Control',
            ],
        },
        dept => $department,
    });
}

sub test_qc_all_items_pass : Tests {
    my ( $self ) = @_;
    test_prefix 'QC All OK';
    $self->test_qc( 10, 0 );
}

sub test_qc_some_items_pass : Tests {
    my ( $self ) = @_;
    test_prefix 'QC Some Faulty';
    $self->test_qc( 10, 5 );
}

sub test_qc_no_items_pass : Tests {
    my ( $self ) = @_;
    test_prefix 'QC All Faulty';
    $self->test_qc( 10, 10 );
}

sub test_qc {
    my ( $self, $num_total, $num_faulty ) = @_;

    # default total and faulty counts if none supplied
    $num_total //= 10;
    $num_faulty //= 0;
    my $num_ok = $num_total - $num_faulty;

    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

    # create a new product so start with limited data, and pick one variant
    my ( undef, $pids ) = Test::XTracker::Data->grab_products({
        force_create => 1,
    });
    my $product = $pids->[0]{product};
    # Get our variant in the same way we get it in setup_purchase_order helps
    # prevent random test failures
    my $variant = $product->search_related(
        'variants', undef, { order_by => 'me.id' }
    )->slice(0,0)->single;

    # get purchase order and stock order details
    my $purchase_order = Test::XTracker::Data->setup_purchase_order([ $product->id ], { confirmed=>1 });
    my $stock_order = $purchase_order->stock_orders->search(undef, { order_by => { -desc => 'id' } })->slice(0, 0)->single;

    # goods in

    $self->{framework}->flow_mech__select_printer_station( {
     section => 'GoodsIn',
     subsection => 'StockIn',
    } );

    $self->{framework}->flow_mech__select_printer_station_submit;

    $self->{framework}
        ->flow_mech__goodsin__stockin
        ->flow_mech__goodsin__stockin_search({ purchase_order_number => $purchase_order->id })
        ;

    # packing slip
    #   (processing packing slip creates a delivery)
    $self->{framework}
        ->flow_mech__goodsin__stockin_packingslip( $stock_order->id )
        ->flow_mech__goodsin__stockin_packingslip__submit({ $variant->sku => $num_total })
        ;

    # stock order should now have a corresponding delivery
    my $delivery = $stock_order->deliveries->slice(0, 0)->single;

    # check no stock processes before we count items
    is $self->_stock_processes_for_variant_in_stock_order( $variant, $stock_order )->count,
        0, 'should have no stock processes before item count';

    set_printer_station( $self->{framework}, 'GoodsIn', 'ItemCount' );

    #   (counting items should create one stock process containing all the items)
    $self->{framework}
        ->flow_mech__goodsin__itemcount
        ->flow_mech__goodsin__itemcount_deliveryid( $delivery->id )
        ->flow_mech__goodsin__itemcount_submit_counts({ counts => { $variant->sku => $num_total } })
        ;

    # check we have one stock process after we count items
    is $self->_stock_processes_for_variant_in_stock_order( $variant, $stock_order )->count,
        1, 'should have one stock process after item count';

    # Set Printer Station for ReturnsQC
    set_printer_station( $self->{framework}, 'GoodsIn', 'QualityControl' );

    # quality control
    #   (QC should split the stock process if there's more than one status, but
    #   should not create a stock process containing no items)
    my ($faulty_tote_id) = Test::XT::Data::Container->get_unique_ids;
    $self->{framework}
        ->flow_mech__goodsin__qualitycontrol
        ->flow_mech__goodsin__qualitycontrol_deliveryid( $delivery->id )
        ->flow_mech__goodsin__qualitycontrol_processitem_submit({
                qc => {
                    faulty_container => $faulty_tote_id,
                    $variant->sku => { checked => $num_total, faulty => $num_faulty },
                },
            })
        ;

    # check we still have one or two stock processes after QC (ok/faulty/both)
    my $expected_stock_processes = ($num_faulty ? 1 : 0) + ($num_ok ? 1 : 0);
    is $self->_stock_processes_for_variant_in_stock_order( $variant, $stock_order )->count,
        $expected_stock_processes, 'should have '.$expected_stock_processes .
            ' stock process'.($expected_stock_processes == 1 ? '' : 'es') .
            ' after QC';

    my %stock_type_quantity = ( main => $num_ok, faulty => $num_faulty, );
    # expect a pre_advice message to be sent if any items passed QC
    my @expected_messages = map{
            {
                type => 'pre_advice',
                details => {
                    items => [
                        {
                            skus => [
                                {
                                    sku => $variant->sku,
                                    quantity => $stock_type_quantity{$_},
                                },
                            ],
                        },
                    ],
                    stock_status => $_,
                },
            },
        } grep {
            # We don't send messages for process groups with 0 quantity
            $stock_type_quantity{$_}
            # We don't send IWS messages for faulty process groups
         && !( $distribution_centre eq 'DC1' && $_ eq 'faulty' )
        } keys %stock_type_quantity ;

    my @messages;
    (@messages) = $xt_to_wms->expect_messages({
        verbose => 1,
        messages => \@expected_messages,
    }) if @expected_messages;
}

sub set_printer_station {
    my ( $framework, $section, $subsection, $channel_id ) = @_;

    $framework->flow_mech__select_printer_station( {
        section => $section,
        subsection => $subsection,
        channel_id => $channel_id,
    } );
    $framework->flow_mech__select_printer_station_submit;

    return;
}

sub _stock_processes_for_variant_in_stock_order {
    my ( $self, $variant, $stock_order ) = @_;

    # this gets the latest stock order for the variant, gets the first delivery
    # item from that and returns the stock processes for that delivery item.

    return $variant
        ->stock_order_items->search({ stock_order_id => $stock_order->id })->slice(0,0)->single
        ->delivery_items->slice(0,0)->single
        ->stock_processes;
}


Test::Class->runtests;
