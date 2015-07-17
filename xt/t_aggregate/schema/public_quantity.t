#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

# load the module that provides all of the common test functionality
use FindBin::libs;
use Test::Most;

use XTracker::Constants::FromDB qw( :flow_status );
use Test::XTracker::Data;
use Data::Dump qw(pp);
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::Quantity',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                variant_id
                location_id
                quantity
                zero_date
                channel_id
                status_id
                date_created
            ]
        ],

        relations => [
            qw[
                location
                channel
                product_variant
                voucher_variant
                status
                rtv_quantity
            ]
        ],

        custom => [
            qw[
                variant
                update_quantity
                delete_and_log
                update_and_log_sample
                is_in_main_stock
                is_in_dead_stock
                is_in_creative
                is_in_quarantine
                is_in_sample
                is_in_transit_from_iws
                is_rtv_transfer_pending
                is_transfer_pending
            ]
        ],

        resultsets => [
            qw[
                move_stock
                validate_move_stock
                get_empty_locations
            ]
        ],
    }
);

$schematest->run_tests();

#################################
# Test some of the custom methods
#

my $schema = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema',"Schema Created");

#
# Test move_stock
#

$schema->txn_do(sub{
    # set up some data
    my $channel     = $schema->resultset('Public::Channel')->search(undef, {rows=>1})->single;
    my $operator    = $schema->resultset('Public::Operator')->search(undef, {rows=>1})->single;
    my $main_status = $schema->resultset('Flow::Status')->find($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS);
    my $loc_rs  = $schema->resultset('Public::Location');
    my @main_locs;
    foreach my $count ((0..2)){
        my $loc = $loc_rs->create({
            location => "main location $count",
        });
        $loc->add_to_location_allowed_statuses({status_id => $main_status->id});
        push @main_locs, $loc;
    }
    my (undef,$pids) = Test::XTracker::Data->grab_products({how_many=>1});
    my $variant = $pids->[0]->{variant};
    my $rs      = $schema->resultset('Public::Quantity');
    my $lrs     = $schema->resultset('Public::LogLocation');

    # clearly we have no variants in this location in this new state yet
    is($rs->find({variant_id  => $variant->id,
                  location_id => $main_locs[0]->id,
                  channel_id  => $channel->id,
                  status_id   => $main_status->id}), undef, 'No quantity rows matching yet');

    # Test Errors
    my $param = {};
    throws_ok { $rs->move_stock($param) } qr/Required argument 'variant' not defined\.?; Required argument 'channel' not defined\.?; Required argument 'quantity' must be an integer > 0\.?; Argument 'from' is required, though it can be undefined\.?; Argument 'to' is required, though it can be undefined\.?; Arguments 'from' and 'to' cannot both be undef/, 'Loads of errors with no params';

    $param = {
        variant     => 99999999,
        channel     => 'NAN',
        quantity    => 'NAN',
        from        => 1,
        to          => {location => {}, },
        log_location_as => 'NAN',
    };
    throws_ok { $rs->move_stock($param) } qr/^variant with id 99999999 not found\.?; Required argument 'channel' must be an integer or a \S+ object\.?; Required argument 'quantity' must be an integer > 0\.?; Argument 'from' must be a hashref if defined\.?; If defined, argument 'to' must have a key 'location' containing an id, a location or a \S+ object.\.?; If defined, argument 'to' must have a key 'status' defined\.?; If defined, argument 'log_location_as' must have a key containing an operator id or object./, 'Check various param types';

    $param = {
        variant     => $variant->id,
        channel     => $channel->id,
        quantity    => 0,
        from        => undef,
        to          => { location => 'non-existant location name',
                         status   => 99999999, },
        log_location_as => 99999999,,
    };
    throws_ok { $rs->move_stock($param) } qr/^Required argument 'quantity' must be an integer > 0\.?; 'to' location with name 'non-existant location name' not found\.?; 'to' status with id 99999999 not found\.?; operator with id 99999999 not found/, 'More stoopid params';



    # Test successful create using IDs
    $param = {
        variant     => $variant->id,
        channel     => $channel->id,
        quantity    => 1,
        from        => undef,
        to          => { location => $main_locs[0]->id,
                         status  => $main_status->id, }
    };

    lives_ok {$rs->move_stock($param)} "lives with 'from' set to undef, so creating a new quantity";
    ok($rs->find({variant_id  => $variant->id,
                  location_id => $main_locs[0]->id,
                  channel_id  => $channel->id,
                  status_id   => $main_status->id}), 'Quantity row has been inserted');
    is($lrs->find({variant_id  => $variant->id,
                   location_id => $main_locs[0]->id,
                   channel_id  => $channel->id}), undef, 'No location logged yet');

    # Try moving more than we have
    $param->{quantity}      = 2,
    $param->{from}          = { location => $main_locs[0]->id,
                                status   => $main_status->id, };
    $param->{to}            = undef;
    throws_ok { $rs->move_stock($param) } 'DBIx::Class::Exception', 'Cannot move more than there are in location';
    like $@, qr/Not enough stock in 'from' location to move/, 'Correct error';

    # Try moving to invalid status
    $param->{quantity}      = 1,
    $param->{from}          = { location => $main_locs[0]->id,
                                status   => $main_status->id, },
    $param->{to}            = { location => $main_locs[0]->id,
                                status   => $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS, };
    throws_ok { $rs->move_stock($param) } qr/^Can't move from status 'Main Stock' to 'RTV Workstation'\.?; Location 'main location 0' does not accept next status 'RTV Workstation'/, 'Invalid stock flow and location status';

    # Successful delete
    $param->{from}              = { location => $main_locs[0]->id,
                                    status   => $main_status->id, };
    $param->{to}                = undef;
    $param->{log_location_as}   = $operator->id;

    lives_ok {$rs->move_stock($param)} "'to' set to undef, so deleting quantity";
    is($rs->find({variant_id  => $variant->id,
                  location_id => $main_locs[0]->id,
                  channel_id  => $channel->id,
                  status_id   => $main_status->id}), undef, 'Quantity row has been deleted');
    ok($lrs->find({variant_id  => $variant->id,
                   location_id => $main_locs[0]->id,
                   channel_id  => $channel->id}), 'Location logged now');


    # test success with objects / location names
    $param = {
        variant     => $variant,
        channel     => $channel,
        quantity    => 1,
        from        => undef,
        to          => { location => $main_locs[1]->location,
                         status   => $main_status, },
    };
    lives_ok {$rs->move_stock($param)} 'created quantity';
    ok($rs->find({variant_id  => $variant->id,
                  location_id => $main_locs[1]->id,
                  channel_id  => $channel->id,
                  status_id   => $main_status->id}), 'Quantity row has been inserted');

    $param->{from} = { location => $main_locs[1],
                       status   => $main_status, };
    $param->{to}   = { location => $main_locs[2],
                       status   => $main_status, };
    lives_ok {$rs->move_stock($param)} 'moved stock';
    is($rs->find({variant_id  => $variant->id,
                  location_id => $main_locs[1]->id,
                  channel_id  => $channel->id,
                  status_id   => $main_status->id}), undef, 'Quantity row has been moved');
    ok($rs->find({variant_id  => $variant->id,
                  location_id => $main_locs[2]->id,
                  channel_id  => $channel->id,
                  status_id   => $main_status->id}), 'Quantity row has been moved');

    $param->{keep_if_zero}  = 1;
    $param->{from}          = { location     => $main_locs[2],
                                status       => $main_status, };
    $param->{to}            = undef;
    lives_ok {$rs->move_stock($param)} 'removed stock';
    my $stock;
    ok($stock = $rs->find({ variant_id  => $variant->id,
                            location_id => $main_locs[2]->id,
                            channel_id  => $channel->id,
                            status_id   => $main_status->id}), 'Quantity row has not been deleted');
    is($stock->quantity, 0, 'But it has zero stock');

    $schema->txn_rollback;
});

done_testing;
