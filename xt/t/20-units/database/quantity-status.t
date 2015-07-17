#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::Data;
use XTracker::Schema;
use XTracker::Database qw(get_database_handle);
use XTracker::Constants::FromDB qw( :flow_status :flow_type );
use XTracker::Database::Stock qw(:DEFAULT check_stock_location);
use Test::Most 'die';

my $schema = get_database_handle(
    {
        name    => 'xtracker_schema',
    }
);
isa_ok($schema, 'XTracker::Schema',"Schema Created");

$schema->txn_do(
    sub{
        # NOTE: the alterating usage of $dbh and $schema is
        # intentional, it's used to test that the function behave
        # correctly regardless of which one you pass
        my $dbh=$schema->storage->dbh;

        my $channel=$schema->resultset('Public::Channel')->search(undef,{rows=>1})->single;
        my @variants= map { $_->{variant} }
            @{ Test::XTracker::Data->grab_products({how_many=>5}) };

        my $special_status=$schema->resultset('Flow::Status')->create({
            name => 'test special',
            type_id => $FLOW_TYPE__STOCK_STATUS,
            is_initial => 0,
        });
        $special_status->add_to_prev_status({current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS});
        $special_status->add_to_next_status({next_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS});

        my $loc_rs=$schema->resultset('Public::Location');

        my $main_loc=$loc_rs->create({
            location => 'test main location',
        });
        $main_loc->add_to_location_allowed_statuses({status_id=>$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS});

        my $mixed_loc=$loc_rs->create({
            location => 'test mixed location',
        });
        $mixed_loc->add_to_location_allowed_statuses(
            {status_id=>$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS},
        );
        $mixed_loc->add_to_location_allowed_statuses(
            {status_id=>$FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS}
        );
        $mixed_loc->add_to_location_allowed_statuses(
            {status_id=>$special_status->id}
        );

        throws_ok {
            insert_quantity($schema,{
                location => 'definitely no such location',
                quantity => 10,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                initial_status => 'Main Stock',
            });
        } qr{Unknown location} , q{can't insert in non-existing loc};

        throws_ok {
            update_quantity($dbh,{
                location => 'definitely no such location',
                quantity => 10,
                channel_id => $channel->id,
                type => 'inc',
                variant_id => $variants[0]->id,
                current_status => 'Main Stock',
            });
        } qr{Unknown location} , q{can't update in non-existing loc};

        throws_ok {
            delete_quantity($schema,{
                location => 'definitely no such location',
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status => 'Main Stock',
            });
        } qr{Unknown location} , q{can't delete from non-existing loc};

        throws_ok {
            insert_quantity($dbh,{
                location_id => $main_loc->id,
                quantity => 10,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                initial_status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
            });
        } qr{does not accept initial status} , q{can't insert in main loc w/ non-main status};

        lives_ok {
            insert_quantity($schema,{
                location_id => $main_loc->id,
                quantity => 9,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        } q{can insert in main loc w/ main status};

        lives_ok {
            insert_quantity($dbh,{
                location_id => $mixed_loc->id,
                quantity => 8,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        } q{can insert in mixed loc w/ main status};

        lives_ok {
            insert_quantity($schema,{
                location_id => $mixed_loc->id,
                quantity => 7,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                initial_status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
            });
        } q{can insert in mixed loc w/ non-main status};

        throws_ok {
            insert_quantity($schema,{
                location_id => $mixed_loc->id,
                quantity => 10,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                initial_status_id => $special_status->id,
            });
        } qr{not a valid initial status},q{can't insert in mixed loc w/ non-initial status};

        lives_ok {
            insert_quantity($dbh,{
                location_id => $mixed_loc->id,
                quantity => 6,
                channel_id => $channel->id,
                variant_id => $variants[1]->id,
                initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        } q{can insert in mixed loc w/ main status (second variant)};

        ok(check_stock_location($schema,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        }),q{can find quantity in main location});

        ok(!check_stock_location($dbh,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        }),q{no quantity in main location non-main status});

        ok(check_stock_location($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        }),q{can find quantity in mixed location main status});

        ok(check_stock_location($dbh,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS
        }),q{can find quantity in mixed location non-main status});

        ok(check_stock_location($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[1]->id,
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        }),q{can find quantity in mixed location main status second variant});

        ok(!check_stock_location($dbh,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[1]->id,
                status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        }),q{no quantity in mixed location non-main status second variant});

        is(get_stock_location_quantity($dbh,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        }),9,q{correct quantity in main location});

        is(get_stock_location_quantity($schema,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        }),0,q{correct 0 quantity in main location non-main status});

        is(get_stock_location_quantity($dbh,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        }),8,q{correct quantity in mixed location main status});

        is(get_stock_location_quantity($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS
        }),7,q{correct quantity in mixed location non-main status});

        is(get_stock_location_quantity($dbh,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[1]->id,
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        }),6,q{correct quantity in mixed location main status second variant});

        is(get_stock_location_quantity($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[1]->id,
                status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        }),0,q{correct 0 quantity in mixed location non-main status second variant});

        throws_ok {
            update_quantity($schema,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => 1, type => 'dec',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        } qr{Positive Value Passed},q{dec w/ positive};

        throws_ok {
            update_quantity($schema,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => -1, type => 'inc',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        } qr{Negative Value Passed},q{inc w/ negative};

        throws_ok {
            update_quantity($schema,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => 0, type => 'inc',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        } qr{Zero Value Passed},q{inc w/ zero};

        throws_ok {
            update_quantity($schema,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => 0, type => 'dec',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        } qr{Zero Value Passed},q{dec w/ zero};

        throws_ok {
            update_quantity($schema,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => 13, type => 'inc',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                next_status_id => $FLOW_STATUS__QUARANTINE__STOCK_STATUS,
            });
        } qr{Can't move},q{bad status transition};

        throws_ok {
            update_quantity($schema,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => 13, type => 'inc',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                next_status_id => $special_status->id,
            });
        } qr{does not accept next status},q{bad next status for location};

        lives_ok {
            update_quantity($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => 0, type => 'inc',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                next_status_id => $special_status->id,
            });
        } q{status transition w/o quantity change};

        is(get_stock_location_quantity($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $special_status->id,
        }),8,q{correct quantity in mixed location after transition});

        lives_ok {
            update_quantity($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => 10, type => 'inc',
                current_status_id => $special_status->id,
            });
        } q{quantity change w/o status transition};

        is(get_stock_location_quantity($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $special_status->id,
        }),18,q{correct quantity in mixed location after update});

        # NOTE: this test is transitional, you shouldn't be able to
        # call "update_quantity" w/o a current_status_id, but it's
        # needed for the time being

        for my $q ($schema->resultset('Public::Quantity')->search({
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
            })->all) {
            note sprintf '-- loc %d var %d ch %d q %d status %s(%d)',
                $q->location_id,$q->variant_id,$q->channel_id,
                $q->quantity,$q->status->name,$q->status_id;
        }

        lives_ok {
            delete_quantity($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => 0, type => 'inc',
                status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS
            });
        } q{delete quantities};

        lives_ok {
            update_quantity($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                quantity => 0, type => 'inc',
                current_status_id => $special_status->id,
                next_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        } q{status transition w/o quantity change and no current status};

        is(get_stock_location_quantity($schema,{
                location_id => $mixed_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[0]->id,
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        }),18,q{correct quantity in mixed location after transition});

        # This test should not really pass, but some weirdness in the
        # putaway process requires it. Please help fixing the real
        # reasons (info: taking stuff out of RTV, we should decrement
        # quantities in the "RTV Transfer Pending" location, but
        # sometimes the stock is not there)
        lives_ok {
            update_quantity($schema,{
                location_id => $main_loc->id,
                channel_id => $channel->id,
                variant_id => $variants[3]->id,
                quantity => -2, type => 'dec',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                next_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        } q{update_quantity does not die if asked to remove stock that does not exist};

        $schema->txn_rollback;
    });

done_testing();
