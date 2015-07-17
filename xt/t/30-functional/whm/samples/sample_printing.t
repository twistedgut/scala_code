#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

sample_printing.t - Test that a sample putaway sheet / stock sheet is printed

=head1 DESCRIPTION

Test that a sample putaway sheet / stock sheet is printed.

#TAGS duplication printer sample fasttrack goodsin checkruncondition whm

=head1 SEE ALSO

sample_picklist.t

=cut

use FindBin::libs;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB
    qw(
          :authorisation_level
          :stock_order_status
  );
use Test::Most;
use XTracker::Config::Local qw(config_var);
use Test::More::Prefix qw/test_prefix/;

use Test::XTracker::RunCondition dc => 'DC2';
use XT::Rules::Solve;
use Test::XTracker::PrintDocs;
test_prefix('Setup');
my $schema = Test::XTracker::Data->get_schema;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::Samples',
        'Test::XT::Data::Samples',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::StockControl',
        'Test::XT::Flow::PrintStation',
        'Test::XT::Feature::AppMessages',
    ],
);
$framework->mech->force_datalite(1);
my $channel = Test::XTracker::Data->get_local_channel('OUTNET');

test_prefix('Setup data');

my $po = Test::XTracker::Data->create_from_hash({
    channel_id      => $channel->id,
    placed_by       => 'Test User',
    stock_order     => [{
        status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
        product         => {
            size_scheme_id => 2,
            product_type_id => 6, # Dresses
            style_number    => 'Test Style',
            variant         => [{
                size_id => 10,
                stock_order_item    => {
                    quantity            => 10,
                },
            },{
                size_id => 11,
                stock_order_item    => {
                    quantity            => 10,
                },
            }],
            product_channel => [{
                channel_id      => $channel->id,
                live            => 0,
            }],
            product_attribute => {
                description     => 'Test Description',
            },
        },
    }],
});

my ($delivery) = Test::XTracker::Data->create_delivery_for_po($po->id, 'qc');
my ($sp) = Test::XTracker::Data->create_stock_process_for_delivery($delivery);

my (@variants) = $po->stock_orders
    ->related_resultset('stock_order_items')
    ->related_resultset('variant')->all;

my @fast_track_skus = map { $_->sku } @variants;

test_prefix('Fast track');
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Goods In/Quality Control',
    ]},
    dept => 'Distribution'
});


# fast track one of each sku = no error
$framework->flow_mech__goodsin__fasttrack_deliveryid($delivery->id);

my $print_directory = Test::XTracker::PrintDocs->new();

$framework->flow_mech__goodsin__fasttrack_submit({
    fast_track => { map { $_ => 1 } @fast_track_skus },
});

$framework->mech->no_feedback_error_ok("No error when fast-tracking with non-zero quantity");

my @print_dir_new_file = $print_directory->wait_for_new_files( files => 1  );

is( scalar( @print_dir_new_file ), 1, 'Correct number of files printed' );

# first file should always be delivery
is( $print_dir_new_file[0]->{file_type}, 'fasttrack', 'Correct file type' );
is( $print_dir_new_file[0]->{printer_name}, 'fasttrack', 'Sent to the correct printer' );
is( $print_dir_new_file[0]->{copies}, 1, 'Correct number of copies' );

note 'Clearing all test locations';
$framework->data__location__destroy_test_locations;

done_testing;

