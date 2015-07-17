#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;

use Data::Dumper;
use Test::MockModule;

BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Database::StockProcess', qw(
                            get_suggested_measurements
                        ));
    use_ok('XTracker::Schema::Result::Public::Product');
}

my $schema  = Test::XTracker::Data->get_schema();
my $dbh     = $schema->storage->dbh;

#---- Test Functions ------------------------------------------

_test_measurement_funcs($schema);

#--------------------------------------------------------------

done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# This tests the product type measurement code
sub _test_measurement_funcs {

    my $schema  = shift;

    # Note: the test product types below have been chosen to test various configurations
    # of measurement:product type mappings. If the mappings change it might make sense
    # to update the product types used in the test to make sure it's still covering all
    # the different options.
    my @product_types = (
        'Activewear', #   measurements only on NAP and OUT
        'Cufflinks',  #   measurements only on MRP
        'Bags',       #   measurement types differ between NAP/OUT and MRP
        'Belts',      #   measurements the same across NAP, OUT and MRP
        'Luggage',    #   no measurements on any channel
        'Suits',      #   measurements with sort order
    );

    $schema->txn_do( sub {
        note "Testing 'get_suggested_measurements' and 'requires_measuring'";

        # requires_measuring is DC-dependent - and the logic for that is in
        # XT::Rules. Let's override that so this test runs in the same way on
        # all DCs. Note that I'm lazy and am bluntly mocking any calls to
        # XT::Rules - so any new rules will be mocked too. Sorry.
        my $module = Test::MockModule->new('XT::Rules::Solve');
        $module->mock(solve => sub {note 'Calling mocked XT::Rules definition'; 1});
        foreach my $channel ( Test::XTracker::Data->get_enabled_channels()->all ) {
            my $channel_id = $channel->id;
            note "Testing channel id $channel_id";
            foreach my $product_type (@product_types) {

                my $product_type_id = $schema->resultset('Public::ProductType')->search({
                    product_type => $product_type
                })->first->id;

                my $wanted =  $schema->resultset('Public::ProductTypeMeasurement')->search({
                    channel_id => $channel_id,
                    product_type_id => $product_type_id,
                })->count;

                my ($product) = Test::XTracker::Data->create_test_products({
                    channel_id => $channel_id,
                    how_many => 1,
                    product_type_id => $product_type_id,
                });
                my $suggested = get_suggested_measurements($dbh, $product->id());
                is(scalar @$suggested, $wanted,
                    "Product type $product_type ($product_type_id) on channel $channel_id has $wanted suggested measurements");
                if ($wanted) {
                    ok($product->requires_measuring,
                        "Product type $product_type ($product_type_id) on channel $channel_id requires measuring");
                } else {
                    ok(!$product->requires_measuring,
                        "Product type $product_type ($product_type_id) on channel $channel_id doesn't require measuring");
                }
                foreach my $suggested_measurement (@$suggested) {
                    my $found = $schema->resultset('Public::ProductTypeMeasurement')->search({
                        channel_id => $channel_id,
                        product_type_id => $product_type_id,
                        measurement_id => $suggested_measurement->{id}
                    })->first;
                    isnt($found, undef, "Matching measurement for ".$suggested_measurement->{measurement}." found in db");
                    if ($found && $found->sort_order) {
                        is ($suggested_measurement->{sort_order}, $found->sort_order, "Sort order matches");
                    }
                }
            }
        }

        # undo any changes
        $schema->txn_rollback();
    });
}

#--------------------------------------------------------------
