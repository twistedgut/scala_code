#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

stock.t - Unit tests for stock operations in XTracker::Database::Stock

=head1 DESCRIPTION

Tests inserting/updating/deleting quantity records

    AND

Tests inserting/updating/deleting quantity records by location id

    * Test Inserting with a ZERO quantity and updating/deleting from that record
    * Test Inserting with NON ZERO quantity and updating/deleting from that record

Test errors:

    * can't insert a negative quantity
    * can't decrement a positive quantity
    * can't increment a negative quantity
    * can't update quantity with zero
    * can't update with an invalid type

Use the following methods from XTracker::Database::Stock:

    * check_stock_location
    * insert_quantity
    * get_stock_location_quantity
    * check_stock_location
    * update_quantity

#TAGS toobig needsrefactor sql pws shouldbeunit needswork

=cut

use FindBin::libs;

use XTracker::Constants             qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB     qw( :pws_action :shipment_item_status :flow_status );
use Test::XTracker::Data;
use Test::XTracker::Mock::Handler;


use Test::Exception;

# evil globals
our ($dbh,$user_id);

BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Logfile',qw( xt_logger ));
    use_ok('XTracker::Error');
    use_ok('XTracker::Handler');
    use_ok('XTracker::Database::Stock', qw<
        check_stock_location
        get_stock_location_quantity
        update_quantity
        insert_quantity
        delete_quantity

        check_stock_count_variant
        get_total_item_quantity
        get_allocated_item_quantity
        get_picked_item_quantity
        get_saleable_item_quantity
        get_reserved_item_quantity
        get_total_pws_stock
    >);

    can_ok("XTracker::Database::Stock", qw<
        check_stock_location
        get_stock_location_quantity
        update_quantity
        insert_quantity
        delete_quantity

        check_stock_count_variant
        get_total_item_quantity
        get_allocated_item_quantity
        get_picked_item_quantity
        get_saleable_item_quantity
        get_reserved_item_quantity
        get_total_pws_stock
    >);
}

# get a DBH to query
$dbh = Test::XTracker::Data->get_dbh;
isa_ok($dbh, 'DBI::db','DB Handle Created');

# Setup Handler
my $handler = Test::XTracker::Mock::Handler->new({ data => {} });
isa_ok($handler,'Test::MockObject','Mock Handler Created');

_get_data();

#--------------- Run TESTS ---------------

_test_quantity_location(1);
_test_quantity_location_id(1);
_test_errors(1);
_test_stock_funcs(1);

#--------------- END TESTS ---------------

done_testing;

#----------------------- Test Functions -----------------------

# Tests inserting/updating/deleting quantity records
sub _test_quantity_location {
    my $dbh = $handler->{dbh};
    SKIP: {
        skip "_test_quantity_location",1 if (!shift);

        my ($qid,$qtyok,$updqid,$qtysum) = (undef,undef,undef,undef);

        $qtyok = check_stock_location($dbh,{
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtyok,"==",0,"Location Should be Empty");

        # Test Inserting with a ZERO quantity and updating/deleting from that record
        $qid = insert_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => 0,
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qid,">",$handler->{data}{max_qid},"New Quantity Id > Max Quantity Id");
        $handler->{data}{max_qid}       = $qid;

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",0,"Quantity Should be 0");

        $qtyok  = check_stock_location($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtyok,"==",1,"Location Have a Quantity Record");

        $updqid = update_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => 5,
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            type => 'inc',
            current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($updqid,"==",$qid,"Update Quantity Id = Insert Quantity Id");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",5,"Quantity Should be 5");

        $updqid = update_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => -3,
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            type => 'dec',
            current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($updqid,"==",$qid,"Update Quantity Id = Insert Quantity Id");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",2,"Quantity Should be 2");

        delete_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });

        $qtyok  = check_stock_location($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtyok,"==",0,"Location Should be Empty");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",0,"Quantity Should be 0");

        # Test Inserting with NON ZERO quantity and updating/deleting from that record
        $qid    = insert_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => 7,
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qid,">",$handler->{data}{max_qid},"New Quantity Id > Max Quantity Id");
        $handler->{data}{max_qid}       = $qid;

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",7,"Quantity Should be 7");

        $updqid = update_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => 6,
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            type => 'inc',
            current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($updqid,"==",$qid,"Update Quantity Id = Insert Quantity Id");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",13,"Quantity Should be 13");

        $updqid = update_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => -5,
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            type => 'dec',
            current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($updqid,"==",$qid,"Update Quantity Id = Insert Quantity Id");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",8,"Quantity Should be 8");

        delete_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });

        $qtyok  = check_stock_location($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtyok,"==",0,"Location Should be Empty");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",0,"Quantity Should be 0");

        $dbh->rollback();
    }
}

# Tests inserting/updating/deleting quantity records by location id
sub _test_quantity_location_id {
    my $dbh = $handler->{dbh};
    SKIP: {
        skip "_test_quantity_location_id",1 if (!shift);

        my ($qid,$qtyok,$updqid,$qtysum) = (undef,undef,undef,undef);

        $qtyok  = check_stock_location($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtyok,"==",0,"Location Should be Empty");

        # Test Inserting with a ZERO quantity and updating/deleting from that record
        $qid    = insert_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => 0,
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qid,">",$handler->{data}{max_qid},"New Quantity Id > Max Quantity Id");
        $handler->{data}{max_qid}       = $qid;

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",0,"Quantity Should be 0");

        $qtyok  = check_stock_location($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtyok,"==",1,"Location Have a Quantity Record");

        $updqid = update_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => 5,
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            type => 'inc',
            current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($updqid,"==",$qid,"Update Quantity Id = Insert Quantity Id");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",5,"Quantity Should be 5");

        $updqid = update_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => -3,
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            type => 'dec',
            current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($updqid,"==",$qid,"Update Quantity Id = Insert Quantity Id");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",2,"Quantity Should be 2");

        delete_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });

        $qtyok  = check_stock_location($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtyok,"==",0,"Location Should be Empty");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",0,"Quantity Should be 0");

        # Test Inserting with NON ZERO quantity and updating/deleting from that record
        $qid    = insert_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => 7,
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qid,">",$handler->{data}{max_qid},"New Quantity Id > Max Quantity Id");
        $handler->{data}{max_qid}       = $qid;

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",7,"Quantity Should be 7");

        $updqid = update_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => 6,
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            type => 'inc',
            current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($updqid,"==",$qid,"Update Quantity Id = Insert Quantity Id");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",13,"Quantity Should be 13");

        $updqid = update_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => -5,
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            type => 'dec',
            current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($updqid,"==",$qid,"Update Quantity Id = Insert Quantity Id");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",8,"Quantity Should be 8");

        delete_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });

        $qtyok  = check_stock_location($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtyok,"==",0,"Location Should be Empty");

        $qtysum = get_stock_location_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location => $handler->{data}{product_info}{location},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qtysum,"==",0,"Quantity Should be 0");

        $dbh->rollback();
    }
}

# Test that the routines are failing properly
sub _test_errors {
    my $dbh = $handler->{dbh};
    SKIP: {
        skip "_test_errors",1 if (!shift);

        my $qid = undef;

        eval {
            insert_quantity($dbh, {
                variant_id => $handler->{data}{variant_id},
                quantity => -1,
                channel_id => $handler->{data}{product_info}{channel_id},
                location_id => $handler->{data}{product_info}{location_id},
                initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        };
        if ($@) {
            cmp_ok(1,"==",1,"Can't Insert Quantity with a Minus");
        }
        else {
            cmp_ok(1,"==",0,"Inserted Quantity with a Minus");
        }

        $qid    = insert_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            quantity => 0,
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
        cmp_ok($qid,">",$handler->{data}{max_qid},"New Quantity Id > Max Quantity Id");

        eval {
            update_quantity($dbh, {
                variant_id => $handler->{data}{variant_id},
                quantity => 5,
                channel_id => $handler->{data}{product_info}{channel_id},
                location_id => $handler->{data}{product_info}{location_id},
                type => 'dec',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        };
        if ($@) {
            cmp_ok(1,"==",1,"Can't Update Quantity with a Positive & Say it's Decrementing");
        }
        else {
            cmp_ok(1,"==",0,"Updated Quantity with a Positive & Say it's Decrementing");
        }

        eval {
            update_quantity($dbh, {
                variant_id => $handler->{data}{variant_id},
                quantity => -5,
                channel_id => $handler->{data}{product_info}{channel_id},
                location_id => $handler->{data}{product_info}{location_id},
                type => 'inc',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        };
        if ($@) {
            cmp_ok(1,"==",1,"Can't Update Quantity with a Minus & Say it's Incrementing");
        }
        else {
            cmp_ok(1,"==",0,"Updated Quantity with a Minus & Say it's Incrementing");
        }

        eval {
            update_quantity($dbh, {
                variant_id => $handler->{data}{variant_id},
                quantity => 0,
                channel_id => $handler->{data}{product_info}{channel_id},
                location_id => $handler->{data}{product_info}{location_id},
                type => 'inc',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        };
        if ($@) {
            cmp_ok(1,"==",1,"Can't Update Quantity with ZERO");
        }
        else {
            cmp_ok(1,"==",0,"Updated Quantity with ZERO");
        }

        eval {
            update_quantity($dbh, {
                variant_id => $handler->{data}{variant_id},
                quantity => -5,
                channel_id => $handler->{data}{product_info}{channel_id},
                location_id => $handler->{data}{product_info}{location_id},
                type => 'dce',
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
        };
        if ($@) {
            cmp_ok(1,"==",1,"Can't Pass Invalid Type to update_quantity()");
        }
        else {
            cmp_ok(1,"==",0,"Passed Invalid Type to update_quantity()");
        }

        delete_quantity($dbh, {
            variant_id => $handler->{data}{variant_id},
            channel_id => $handler->{data}{product_info}{channel_id},
            location_id => $handler->{data}{product_info}{location_id},
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });

        $dbh->rollback();
    }
}

# tests that the various sub-routines can be called
# and they don't fall over
sub _test_stock_funcs {
    my $dbh = $handler->{dbh};
    my $tmp;
    SKIP: {
        skip "_test_stock_qry_funcs",1 if (!shift);

        my $schema  = Test::XTracker::Data->get_schema;
        $dbh        = $schema->storage->dbh;

        $schema->txn_do( sub {
            my $voucher = Test::XTracker::Data->create_voucher();
            my (undef,$pids) = Test::XTracker::Data->grab_products();
            my $prod_id = $pids->[0]{pid};
            my $var_id  = $pids->[0]{variant_id};
            my $channel = Test::XTracker::Data->get_local_channel();
            my $chan_id = $channel->id;
            my $log_rs  = $schema->resultset('Public::LogPwsStock')->search( {}, { order_by => 'id DESC', rows => 2 } );

            # get qty of shipment items already using stock for the product
            my $reserved_stock = $schema->resultset('Public::ShipmentItem')->search({
                variant_id => $var_id,
                shipment_item_status_id => {'<' => $SHIPMENT_ITEM_STATUS__PICKED}
            })->count
                +
                    $schema->resultset('Public::Reservation')->search({
                variant_id => $var_id,
            })->count;

            my $prod_loc    = Test::XTracker::Data->set_product_stock({
                variant_id  => $var_id,
                channel_id  => $chan_id,
                quantity    => 10 + $reserved_stock,
                stock_status => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });
            my $vouch_loc   = Test::XTracker::Data->set_voucher_stock({
                voucher     => $voucher,
                quantity    => 10,
                stock_status => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            });

            note "Test various Query Stock Quantity functions don't fall over";
            my @test_data   = (
                {
                    type    => 'Product',
                    var_id  => $var_id,
                    prod_id => $prod_id,
                },
                {
                    type    => 'Voucher',
                    var_id  => $voucher->variant->id,
                    prod_id => $voucher->id,
                },
            );

            foreach ( @test_data ) {
                my $prod_id = $_->{prod_id},
                my $var_id  = $_->{var_id},
                my $chname  = $channel->name;
                note "using $_->{type}, Id: $prod_id, Var Id: $var_id";

                lives_ok {
                    $tmp = get_total_item_quantity( $dbh, $prod_id );
                } "'get_total_item_quantity'";
                cmp_ok( $tmp->{ $chname }{ $var_id }, '>=', 10, "quantity returned as expected" );
                lives_ok {
                    $tmp = get_allocated_item_quantity( $dbh, $prod_id );
                } "'get_allocated_item_quantity'";
                lives_ok {
                    $tmp = get_picked_item_quantity( $dbh, $prod_id );
                } "'get_picked_item_quantity'";
                lives_ok {
                    $tmp = get_saleable_item_quantity( $dbh, $prod_id );
                } "'get_saleable_item_quantity'";
                cmp_ok( $tmp->{ $chname }{ $var_id }, '>=', 10, "quantity returned as expected" );
                lives_ok {
                    $tmp = get_reserved_item_quantity( $dbh, $prod_id );
                } "'get_reserved_item_quantity'";
                lives_ok {
                    $tmp = get_total_pws_stock( $dbh, { type => 'product_id', id => $prod_id, channel_id => $chan_id } );
                } "'get_total_pws_stock' using product id";
                cmp_ok( $tmp->{ $var_id }{quantity}, '>=', 10, "quantity returned as expected" );
                my $tmp2;
                lives_ok {
                    $tmp2 = get_total_pws_stock( $dbh, { type => 'variant_id', id => $var_id, channel_id => $chan_id } );
                } "'get_total_pws_stock' using variant id";
                cmp_ok( $tmp2->{ $var_id }{quantity}, '>=', 10, "quantity returned as expected" );
                # get_total_pws_stock should return the same info for a variant
                # regardless of how it was called
                is_deeply( $tmp2->{ $var_id }, $tmp->{ $var_id }, "using both product id & variant id returned the same" );
            }

            note "Test other functions";

            note "Test 'log_pws_stock' table";
            my $lgpwsstck   = $schema->resultset('Public::LogPwsStock');
            my %data    = (
                pws_action_id   => $PWS_ACTION__ORDER,
                operator_id     => $APPLICATION_OPERATOR_ID,
                notes           => 'notes here',
                quantity        => 3,
                balance         => 7,
                channel_id      => Test::XTracker::Data->get_local_channel()->id,
            );

            note "Testing with Product Variant Id";
            $data{variant_id}   = $var_id;
            $tmp = $lgpwsstck->create( \%data );
            cmp_ok( $tmp->variant_id, '==', $var_id, "'log_pws_stock' record created with product variant" );

            note "Testing with Voucher Variant Id";
            $data{variant_id}   = $voucher->variant->id;
            $tmp = $lgpwsstck->create( \%data );
            cmp_ok( $tmp->variant_id, '==', $voucher->variant->id, "'log_pws_stock' record created with voucher variant" );

            note "Testing with incorrect Variant Id";
            $data{variant_id}   = -1234;
            $schema->svp_begin('log_pws_stock');
            dies_ok {
                $tmp = $lgpwsstck->create( \%data );
            } "'log_pws_stock' record not created with incorrect variant";
            $schema->svp_rollback('log_pws_stock');

            $schema->txn_rollback();
        } );
    }
}

#--------------------------------------------------------------

# Get some test data out of the database
# 3 Tests
sub _get_data {

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        dont_ensure_stock => 1,
    });

        my $qry =<<QRY
SELECT  MIN(v.id) AS variant_id
FROM    variant v,
                product p,
                product_attribute pa
WHERE           v.product_id = p.id
AND             v.product_id = pa.product_id
QRY
;
        my $sth = $handler->{dbh}->prepare($qry);
        $sth->execute();
        my @data        = $sth->fetchrow_array();
        $handler->{data}{variant_id}    = $data[0];
        cmp_ok($handler->{data}{variant_id},">",0,"Variant Id Valid");

        $qry    =<<QRY
SELECT  p.id AS product_id,
                pa.name,
                l.location,
                l.id AS location_id,
                ch.id AS channel_id,
                ch.name AS sales_channel
FROM    variant v,
                product p,
                product_attribute pa,
                location l,
                channel ch
WHERE   v.id = ?
AND             v.product_id = p.id
AND             v.product_id = pa.product_id
AND             get_product_channel_id(p.id) = ch.id
AND             l.id = (
                        SELECT  MIN(l2.id)
                        FROM    location l2
                        JOIN location_allowed_status las ON las.location_id=l2.id
                        WHERE las.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
                        AND             l2.id NOT IN (
                                SELECT  l3.id
                                FROM    location l3,
                                                quantity q2
                                WHERE   q2.variant_id = v.id
                                AND             l3.id = q2.location_id
                        )
                )
QRY
;
        $sth    = $handler->{dbh}->prepare($qry);
        $sth->execute($handler->{data}{variant_id});
        my $row = $sth->fetchrow_hashref();
        $handler->{data}{product_info}  = $row;
        isa_ok($handler->{data}{product_info},"HASH");

        $qry    =<<QRY
SELECT  MAX(id)
FROM    quantity
QRY
;
        $sth    = $handler->{dbh}->prepare($qry);
        $sth->execute();
        @data   = $sth->fetchrow_array();
        $handler->{data}{max_qid}       = $data[0];
        cmp_ok($handler->{data}{max_qid},">=",0,"Max Quantity Id Valid");
}
