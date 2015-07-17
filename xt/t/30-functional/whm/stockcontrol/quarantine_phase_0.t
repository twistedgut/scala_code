#!/usr/bin/env perl

=head1 NAME

quarantine_phase_0.t - Quarantine goods in several different ways (while IWS is off)

=head1 DESCRIPTION

Find a product and save a snapshot of it using L<Test::XTracker::LocationMigration>.

Perform the quarantine process for the product and save another snapshot.

Compare the current snapshot with the snapshot before quarantine,
again using L<Test::XTracker::LocationMigration>, and ensure stock movements are as expected.

Putaway the product and save a snapshot.

Compare the current snapshot with the snapshot before putaway,
and ensure stock movements are as expected.

#TAGS phase0 quarantine inventory loops putaway rtv goodsin iws checkruncondition whm

=head1 SEE ALSO

quarantine.t

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XT::Flow;
use Test::More::Prefix qw( test_prefix );
use XTracker::Constants::FromDB qw( :authorisation_level :flow_status  );
use XTracker::Database qw(:common);
use XTracker::Config::Local qw( config_var );
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::RunCondition
    iws_phase   => [0],
    database    => 'full',
    export => [qw( $distribution_centre )];

# Login the mechanize object once.
my $mech = Test::XT::Flow->new->login_with_permissions({
    perms => {
        $AUTHORISATION_LEVEL__MANAGER => [
            'Goods In/Putaway',
            'Stock Control/Inventory',
            'Stock Control/Quarantine'
        ]
    }
})->mech;

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

# Check quarantine as faulty or non-faulty moves goods appropriately. The three
# stages we're looking at are: Start, Post-Quarantine, Post-Putaway.
TEST:
for my $test (
    # Non-faulty goods for eventual RTV
    {
        # Product type
        quarantine_type => ['non_faulty'],
        # Type of location to try and do the putaway in to
        putaway_location => $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        # Progressions that we're testing happen
        stock_status    => [ 'Main Stock' => 'RTV Transfer Pending' => 'RTV Process' ],
    },

    # Faulty goods for RTV
    {
        quarantine_type  => ['faulty', 'rtv'],
        putaway_location => $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        stock_status     => [ 'Main Stock' => '' => 'RTV Process' ],
    },

    # Faulty goods for Dead Stock
    {
        quarantine_type  => ['faulty', 'dead'],
        putaway_location => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
        stock_status     => [ 'Main Stock' => '' => 'Dead Stock' ],
    },

    # Faulty goods that weren't really faulty
    {
        quarantine_type  => ['faulty', 'stock'],
        putaway_location => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        stock_status     => [ 'Main Stock' => '' => 'Main Stock' ],
    },
) {
    my $stock_status = $test->{'quarantine_type'}->[0];
    my $fault_type   = $test->{'quarantine_type'}->[1] || '';
    my $description = join ' ',
        map { ucfirst $_ } @{$test->{'quarantine_type'}};

    ok( 1, "Quarantine Test: $description" );

    # Setup our framework object
    my $framework = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::StockControl::Quarantine',
            'Test::XT::Flow::GoodsIn',
            'Test::XT::Feature::LocationMigration',
            'Test::XT::Data::Location'
        ],
        mech => $mech
    );

    $framework->force_datalite(1);
    $framework->data__location__destroy_test_locations;

    # Which stage of the process we're in (index of the progression indexes)
    my $step = 0;

    # Find a product, and find somewhere to put it
    my $product_data = $framework->flow_db__stockcontrol__quarantine_find_product;
    my $quantity     = $product_data->{'variant_quantity'};
    my $variant_id   = $product_data->{'variant_object'}->id;
    my $variant_sku  = $product_data->{'variant_sku'};

    $framework
        ->test_db__location_migration__init( $variant_id )
            ->test_db__location_migration__snapshot('Before Quarantine')

                # Start the quarantine process
                ->flow_mech__stockcontrol__inventory_stockquarantine(
                    $product_data->{'product_object'}->id
                );

    my ($qnote, $quarantine_return) = $framework
        ->flow_mech__stockcontrol__inventory_stockquarantine_submit(
            variant_id => $variant_id,
            location   => $product_data->{'location_from'},
            type       => $stock_status eq 'faulty' ? 'L' : 'V'
        );

    # If we were submitting non-faulty, the quarantine_return will be the process
    # group ID. If we were doing faulty, we'll get it from running the faulty
    # methods.
    my $process_group_id = $quarantine_return;

    $xt_to_wms->new_files();

    # Finish the quarantine process off for faulty goods
    if ( $stock_status eq 'faulty' ) {
        note "Processing faulty item, fault_type='$fault_type'";

        $process_group_id = $framework
            ->flow_mech__stockcontrol__quarantine_processitem(
                $quarantine_return->id
            )->flow_mech__stockcontrol__quarantine_processitem_submit(
                $fault_type => $quantity
            );

        my $target_stock_status = $fault_type eq 'stock' ? 'main' : $fault_type;

        note "Checking for pre-advice message for SKU $variant_sku, quantity $quantity, stock_status $fault_type";

        $xt_to_wms->expect_messages( {
            messages => [ {   type    => 'pre_advice',
                              details => { items => [ { skus => [ { sku      => $variant_sku,
                                                                    quantity => $quantity
                                                                } ]
                                                    } ],
                                           stock_status => $target_stock_status
                                       }
                          } ]
        } );
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

    # Do the putaway
    my $rtv_putaway_location;
    if ($distribution_centre eq 'DC2') {
        # WHM-457 - RTV things need to go to floor 4 in DC2
        $framework->data__location__initialise_non_iws_test_locations;
        my $location_rs = $framework->schema->resultset('Public::Location');
        my $floor = ($fault_type eq 'stock') ? 1 : 4;
        my $putaway_location = $location_rs->get_locations({ floor => $floor })->slice(0,0)->single;
        $rtv_putaway_location = $putaway_location->location;
    } else {
        $rtv_putaway_location = $framework->data__location__create_new_locations({
            quantity    => 1,
            channel_id  => $product_data->{'channel_object'}->id,
        })->[0];
    }
    $framework
        ->flow_mech__goodsin__putaway_processgroupid( $process_group_id );


    $framework
        ->flow_mech__goodsin__putaway_book_submit( $rtv_putaway_location, $quantity )
            ->flow_mech__goodsin__putaway_book_complete()
                ->test_db__location_migration__snapshot('After Putaway');

    # Test the start-to-end of the process. In some cases, we're going to and
    # from the same thing, so need to do something slightly different...
    $framework->test_db__location_migration__test_delta(
        from => 'Before Quarantine',
        to   => 'After Putaway',
        stock_status =>
            ( $test->{'stock_status'}->[ $step - 1 ] eq $test->{'stock_status'}->[ $step + 1 ] )
                ? {} : {
                    $test->{ 'stock_status' }->[ $step - 1 ] => 0-$quantity,
                        $test->{ 'stock_status' }->[ $step + 1 ] => 0+$quantity,
                    }
            );

    $framework->data__location__destroy_test_locations;
}

done_testing();
