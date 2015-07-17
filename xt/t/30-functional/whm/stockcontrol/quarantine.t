#!/usr/bin/env perl

=head1 NAME

quarantine_phase_0.t - Quarantine goods in several different ways (while IWS is on)

=head1 DESCRIPTION

Find a product and save a snapshot of it using L<Test::XTracker::LocationMigration>.

Perform the quarantine process for the product and save another snapshot.

Compare the current snapshot with the snapshot before quarantine,
again using L<Test::XTracker::LocationMigration>, and ensure stock movements are as expected.

Putaway the product and save a snapshot.

Compare the current snapshot with the snapshot before putaway,
and ensure stock movements are as expected.

#TAGS quarantine inventory loops putaway rtv goodsin iws return checkruncondition whm

=head1 SEE ALSO

quarantine_phase_0.t

=cut


use NAP::policy 'test';

use Test::XT::Flow;
use Test::More::Prefix qw( test_prefix );
use XTracker::Constants::FromDB qw( :authorisation_level :flow_status  );
use XTracker::Database qw(:common);
use XTracker::Config::Local qw( config_var config_section_slurp );
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::MessageQueue;
use Test::XTracker::RunCondition iws_phase => [1,2];

# Login the mechanize object once.
my $framework = Test::XT::Flow->new_with_traits( traits => [qw/
    Test::XT::Data::Location
    Test::XT::Feature::LocationMigration
    Test::XT::Flow::GoodsIn
    Test::XT::Flow::PrintStation
    Test::XT::Flow::RTV
    Test::XT::Flow::StockControl::Quarantine
/] );
$framework->login_with_permissions({
    perms => {
        $AUTHORISATION_LEVEL__MANAGER => [
            'Goods In/Putaway',
            'Stock Control/Inventory',
            'Stock Control/Quarantine',
            'RTV/Request RMA',
            'RTV/List RMA',
            'RTV/List RTV',
            'RTV/Pick RTV',
            'RTV/Pack RTV',
            'RTV/Awaiting Dispatch',
            'RTV/Dispatched RTV'
        ]
    }
});
my $mech = $framework->mech;

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');

# Check quarantine as faulty or non-faulty moves goods appropriately. The three
# stages we're looking at are: Start, Post-Quarantine, Post-Putaway.
for my $test (
    # Non-faulty goods for eventual RTV
    {
        description => 'Non-faulty',
        # Product type
        quarantine_type => ['non_faulty'],
        # Type of location to try and do the putaway in to
        putaway_location => $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        # Progressions that we're testing happen
        stock_status    => [ 'Main Stock' => '' => 'RTV Process' ],
        preadvice => '',
        use_transit => 1,
    },

    # Faulty goods for RTV
    {
        description => 'Faulty RTV',
        quarantine_type  => ['faulty', 'rtv'],
        putaway_location => $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        stock_status     => [ 'Main Stock' => '' => 'RTV Process' ],
        preadvice => '',
        use_transit => '',
    },

    # Faulty goods for Dead Stock
    {
        quarantine_type  => ['faulty', 'dead'],
        putaway_location => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
        stock_status     => [ 'Main Stock' => '' => 'Dead Stock' ],
        preadvice => 1,
        use_transit => '',
    },

    # Faulty goods that weren't really faulty
    {
        quarantine_type  => ['faulty', 'stock'],
        putaway_location => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        stock_status     => [ 'Main Stock' => '' => 'Main Stock' ],
        preadvice => 1,
        use_transit => '',
    },
) {

    my $stock_status = $test->{quarantine_type}->[0];
    my $fault_type   = $test->{quarantine_type}->[1] || '';
    my $description =  $test->{description} ||
                           join ' ', map { ucfirst $_ } @{$test->{quarantine_type}};

    my $preadvice   = $test->{preadvice};
    my $use_transit = $test->{use_transit};

    note "Quarantine Test: $description";

    $framework->force_datalite(1);
    $framework->data__location__destroy_test_locations;

    # Which stage of the process we're in (index of the progression indexes)
    my $step = 0;


    note "Quarantining via Transit";

    my ($product_hash) = @{Test::XTracker::Data->grab_products( { how_many => 1 } )};
    my ($iws_stock_status,$iws_reason) = ('main','STOCK OUT TO XT');

    my (  $pid, $variant_id, $variant, $product, $sku, $product_channel ) = @{$product_hash}{
       qw( pid   variant_id   variant   product   sku   product_channel )
    };

    my $channel = $product_channel->channel;

    my $quantity = 1;

    $framework->test_db__location_migration__init( $variant_id )
              ->test_db__location_migration__snapshot('Before Quarantine')
              ->test_db__location_migration__snapshot('Before Inventory Adjust');

    my $payload = {
        sku => $sku,
        quantity_change => -$quantity,
        reason => $iws_reason,
        stock_status => $iws_stock_status,
    };

    my $factory = Test::XTracker::MessageQueue->new();

    $wms_to_xt->new_files;

    $factory->transform_and_send('XT::DC::Messaging::Producer::WMS::InventoryAdjust',$payload);

    $wms_to_xt->expect_messages( {
                    verbose => 1,
                    messages => [ {   type    => 'inventory_adjust',
                                      details => { reason => $iws_reason,
                                                   sku => $sku,
                                                   quantity_change => -$quantity
                                                 }
                                } ]
                     }
                 );

    $framework->test_db__location_migration__snapshot('After Inventory Adjust');

    $framework->test_db__location_migration__test_delta(
        from => 'Before Inventory Adjust',
        to   => 'After Inventory Adjust',
        stock_status => { 'Main Stock'          => -$quantity,
                          'In transit from IWS' => +$quantity
                        }
    );

    $framework->task__set_printer_station(qw/StockControl Quarantine/);
    $framework->flow_mech__stockcontrol__inventory_stockquarantine( $pid );

    my ($quarantine_note, $faulty_item_quantity_obj) =
        $framework->flow_mech__stockcontrol__inventory_stockquarantine_submit(
                    variant_id => $variant_id,
                    location => 'Transit',
                    quantity => $quantity,
                    type => 'L'
                );

    $framework->test_db__location_migration__snapshot('After Transit');

    $framework->test_db__location_migration__test_delta(
        from => 'After Inventory Adjust',
        to   => 'After Transit',
        stock_status => { 'In transit from IWS' => -$quantity,
                           Quarantine           => +$quantity
                        }
    );

    $framework->test_db__location_migration__test_delta(
        from => 'Before Inventory Adjust',
        to   => 'After Transit',
        stock_status => { 'Main Stock' => -$quantity,
                          Quarantine   => +$quantity
                        }
    );

    $xt_to_wms->new_files();

    my $stock_process_group_id = $framework
        ->flow_mech__stockcontrol__quarantine_processitem(
              $faulty_item_quantity_obj->id
        )->flow_mech__stockcontrol__quarantine_processitem_submit(
              ($fault_type||'stock') => $quantity
        );

    # Finish the quarantine process off for faulty goods
    if ( $stock_status eq 'faulty' ) {
        note "Processing faulty item, fault_type='$fault_type'";

        my $target_stock_status = $fault_type eq 'stock' ? 'main' : $fault_type;

        if ($preadvice) {
            note "Checking for pre-advice message for SKU $sku, quantity $quantity, stock_status $fault_type";

            $xt_to_wms->expect_messages( {
                verbose => 1,
                messages => [ {   type    => 'pre_advice',
                                  details => { items => [ { skus => [ { sku      => $sku,
                                                                        quantity => $quantity
                                                                      } ]
                                                        } ],
                                               stock_status => $target_stock_status
                                             }
                            } ]
            } );
        }
        else {
            note "Checking for lack of pre-advice message for SKU $sku, quantity $quantity, stock_status $fault_type";

            $xt_to_wms->expect_messages( {
                verbose => 1,
                unexpected => [ { type    => 'pre_advice',
                                  details => { items => [ { skus => [ { sku      => $sku,
                                                                        quantity => $quantity
                                                                      } ]
                                                        } ],
                                               stock_status => $target_stock_status
                                             }
                              } ]
            } );
        }
    }
    else {
        note "No need to process non-faulty item";
    }

    # Now count the movements
    $framework
    ->test_db__location_migration__snapshot('After Quarantine')
    ->test_db__location_migration__test_delta(
        from => 'Before Quarantine',
        to   => 'After Quarantine',
        stock_status => {
            $test->{'stock_status'}->[ $step ]        => 0-$quantity,
            $test->{'stock_status'}->[ $step + 1 ]    => 0+$quantity,
        },
    );
    $step++;

    if ( $fault_type ) {
        if ( $fault_type ne 'rtv' ) {
            note "Checking that direct putaway is forbidden for non-RTV PGID $stock_process_group_id";

            $framework->errors_are_fatal(0);

            $framework->flow_mech__goodsin__putaway_processgroupid( $stock_process_group_id );

            $framework->mech->has_feedback_error_ok(qr/PGID \d+ is handled by IWS/,
                                                    'PGID '.$stock_process_group_id.' should be handled by IWS');

            $framework->errors_are_fatal(1);
        }
        else {
            note "Performing putaway for RTV PGID $stock_process_group_id";

            my $putaway_location = $framework->data__location__create_new_locations({
                quantity    => 1,
                channel_id  => $channel->id,
            })->[0];

            $framework
                ->flow_mech__goodsin__putaway_processgroupid( $stock_process_group_id )
                ->flow_mech__goodsin__putaway_book_submit( $putaway_location, $quantity )
                ->flow_mech__goodsin__putaway_book_complete();

            $framework
                ->test_db__location_migration__snapshot('After Putaway')
                ->test_db__location_migration__test_delta(
                    from => 'Before Quarantine',
                    to   => 'After Putaway',
                    stock_status => {
                        'Main Stock'  => 0-$quantity,
                        'RTV Process' => 0+$quantity,
                    },
                );

            # Now we need to coax the RTV Flow in to accepting this stuff. It has been
            # written to assume certain attributes tacked on to the framework model, so
            # we're going to need to set those.
            my $product_data = { product => $product, channel => $channel };

            for my $item (qw(product channel)) {
                $framework->meta->add_attribute(
                    $item => { is => 'rw', isa => 'Object' }
                );
                $framework->$item( $product_data->{ $item } );
            }

            # Create an RMA request for our stock sample
            my $rtv_quantity_id = $framework
                ->flow_mech__rtv__requestrma
                ->flow_mech__rtv__requestrma__submit
                ->flow_mech__rtv__requestrma__submit__find_rtv_id_via_qnote(
                    $quarantine_note
                );
            my $rma_request_id = $framework
                ->flow_mech__rtv__requestrma__create_rma_request( $rtv_quantity_id );

            # Prepare to ship
            my $shipment_id = $framework
                ->flow_mech__rtv__requestrma__submit_email({
                    to => 'test@example.com',
                    message => 'Here is your RMA mail'
                 })
                ->flow_mech__rtv__listrma
                ->flow_mech__rtv__listrma__submit( $rma_request_id )
                ->flow_mech__rtv__listrma__view_request( $rma_request_id )
                ->flow_mech__rtv__listrma__update_rma_number({
                    rma_request_id => $rma_request_id,
                    rma_number     => 'RMA' . $rma_request_id,
                    follow_up_date => '2020-01-01',
                })->flow_mech__rtv__listrma__capture_notes( $rma_request_id )
                ->flow_mech__rtv__create_shipment( $rma_request_id );

            $framework
                ->flow_mech__rtv__listrtv( $shipment_id )
                ->flow_mech__rtv__pickrtv( $shipment_id )
                ->flow_mech__rtv__pickrtv_autopick_and_commit( $shipment_id )
                ->flow_mech__rtv__packrtv( $shipment_id )
                ->flow_mech__rtv__packrtv_autopack_and_commit( $shipment_id )
                ->flow_mech__rtv__view_awaiting_dispatch( $shipment_id )
                ->flow_mech__rtv__view_shipment_details( $shipment_id )
                ->flow_mech__rtv__update_shipment_details({
                    airway_bill_id  => 'AWB' . $shipment_id,
                    rtv_shipment_id => $shipment_id
                })
                ->flow_mech__rtv__view_dispatched_shipments({
                    rma_number      => 'RMA' . $rma_request_id,
                    airway_bill_id  => 'AWB' . $shipment_id
                })
                ->flow_mech__rtv__view_dispatched_shipment_details( $shipment_id )
                ->test_db__location_migration__snapshot('After RMA')
                ->test_db__location_migration__test_delta;
        }
    }
    else {
        note "Done with pulling non-faulty item into quarantine";
    }

    $framework->data__location__destroy_test_locations;
}

done_testing();




