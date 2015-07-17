#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-142: Fulfilment -> On Hold Add Additional Columns

This tests the 'get_shipment_hold_list' function from 'XTracker::Database::Distribution'
used by the Fulfilment -> On Hold page, it tests all of the columns that are expected
to be returned are and also tests the different 'types' of On Hold: Regular,
Incomplete Pick and Stock Discrepancy.

=cut


use Data::Dump qw(pp);

use DateTime;
use DateTime::Duration;

use Test::XTracker::Data;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :currency
                                        :customer_category
                                        :shipment_status
                                        :shipment_hold_reason
                                        :shipment_item_status
                                    );
use XTracker::Database::Currency    qw( get_currency_glyph );

use_ok( 'XTracker::Database::Distribution', qw(
                                            get_shipment_hold_list
                                    ) );
can_ok( 'XTracker::Database::Distribution', qw(
                                            get_shipment_hold_list
                                    ) );


my $schema = Test::XTracker::Data->get_schema();
isa_ok( $schema, "XTracker::Schema" );

#------------------------
test_shipment_on_hold( $schema, 1 );
#------------------------

done_testing;

# test the 'get_shipment_hold_list' function
sub test_shipment_on_hold {
    my ( $schema, $run )    = @_;

    my $dbh = $schema->storage->dbh;

    # the gap between the shipment date
    # and the selection, hold and release dates
    my $selection_date_gap  = DateTime::Duration->new( minutes => 16 );
    my $hold_date_gap       = DateTime::Duration->new( days => 4 ) + DateTime::Duration->new( minutes => 31 );
    my $release_date_gap    = DateTime::Duration->new( days => 7 ) + DateTime::Duration->new( minutes => 43 );

    SKIP: {
        skip "skipping 'test_on'", 1         if ( !$run );

        note "TEST: test_shipment_on_hold";

        $schema->txn_do( sub {
            # get customer a Customer Category for later
            my $cust_category   = $schema->resultset('Public::CustomerCategory')
                                        ->search( { id => { '!=' => $CUSTOMER_CATEGORY__NONE } } )
                                            ->first;

            my $order       = _create_test_order();
            my $shipment    = $order->get_standard_class_shipment;
            my $ship_item   = $shipment->shipment_items->first;
            my $si_status_log= $ship_item->shipment_item_status_logs->search( {}, { order_by => 'me.id DESC' } );
            my $channel     = $order->channel;
            my $channel_name= $channel->name;
            my $customer    = $order->customer;

            # update the customer category
            $customer->update( { category_id => $cust_category->id } );

            # get the selection date
            my $select_date = $shipment->date + $selection_date_gap;

            # get the hold date to use in tests
            my $hold_date   = $shipment->date + $hold_date_gap;

            # get the release date to use in tests, and split it
            # up so it can be passed to the 'put_on_hold' function
            my $release_date= $shipment->date + $release_date_gap;
            my %release_date_splitup = (
                                releaseYear => $release_date->year,
                                releaseMonth => $release_date->month,
                                releaseDay => $release_date->day,
                                releaseHour => $release_date->hour,
                                releaseMinute => $release_date->minute,
                            );
            # this is used to check against what comes back from 'get_shipment_hold_list'
            my $release_date_compare    = sprintf("%0.4d%0.2d%0.2d", $release_date->year, $release_date->month, $release_date->day );

            note "test when shipment is not on hold";
            my $tmp = get_shipment_hold_list( $schema );
            my $row     = _find_shipment_in_hash( $tmp, $shipment->id );
            ok( !defined $row, "didn't find shipment when it's not on hold" );

            my %tests   = (
                    "Regular" => {
                        type    => 'Held Shipments',
                        params  => {
                            reason  => $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS,
                            %release_date_splitup,
                        },
                    },
                    "Incomplete Pick" => {
                        type    => 'Incomplete Picks',
                        params  => {
                            reason  => $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK,
                            %release_date_splitup,
                        },
                    },
                    "Stock Discrepancy" => {
                        type    => 'Stock Discrepancies',
                        params  => {
                            reason  => $SHIPMENT_HOLD_REASON__STOCK_DISCREPANCY,
                            %release_date_splitup,
                        },
                    },
                    "Failed Allocation" => {
                        type    => 'Failed Allocations',
                        params  => {
                            reason  => $SHIPMENT_HOLD_REASON__FAILED_ALLOCATION,
                            %release_date_splitup,
                        },
                    },
                );

            # what is expected to come back for a shipment
            my $default_language    = $schema->resultset('Public::Language')->get_default_language_preference;
            my %expected    = (
                        id                  => $shipment->id,
                        shipment_type_id    => $shipment->shipment_type_id,
                        orders_id           => $order->id,
                        order_nr            => $order->order_nr,
                        shipment_total      => sprintf("%0.2f",
                                                                $shipment->shipping_charge
                                                                + $shipment->total_price
                                                                + $shipment->total_tax
                                                                + $shipment->total_duty
                                                       ),
                        customer_category_id=> $cust_category->id,
                        customer_category   => $cust_category->category,
                        customer_class_id   => $cust_category->customer_class_id,
                        customer_class      => $cust_category->customer_class->class,
                        currency_id         => $order->currency_id,
                        currency_glyph      => get_currency_glyph( $dbh, $order->currency->currency ),
                        sales_channel       => $channel->name,
                        shipment_date       => _format_date( $shipment->date ),
                        hold_date           => _format_date( $hold_date ),
                        release_date        => _format_date( $release_date ),
                        reason              => '',  # get this later
                        operator            => $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID )->name,
                        selection_date      => '',  # get this later
                        release_date_compare=> $release_date_compare,
                        language_preference_id => undef,
                        cpl                 => $default_language,
                    );

            note "test with different Hold Types";
            foreach my $test_label ( sort keys %tests ) {
                note "Hold Type: $test_label";
                my $test    = $tests{ $test_label };

                # get the textual reason
                $expected{reason}   = $schema->resultset('Public::ShipmentHoldReason')
                                                ->find( $test->{params}{reason} )
                                                    ->reason;

                $shipment->discard_changes->put_on_hold( {
                                status_id   => $SHIPMENT_STATUS__HOLD,
                                operator_id => $APPLICATION_OPERATOR_ID,
                                norelease   => 0,
                                %{ $test->{params} },
                            } );
                # update the on hold dates for test comparisons
                $shipment->shipment_holds->update( { hold_date => $hold_date } );

                # get the list
                my $list    = get_shipment_hold_list( $schema, $shipment->id );
                isa_ok( $list, "HASH", "'get_shipment_hold_list' returned a hash" );
                my $row     = _find_shipment_in_hash( $list, $shipment->id, $channel_name, $test->{type} );
                ok( defined $row, "found the Shipment Id in the hash for Sales Channel: $channel_name & Type: ".$test->{type} );
                isa_ok( $row, "HASH", "the data for the shipment" );
                is_deeply( $row, \%expected, "the data for the shipment is as expected" );

                note "and again but with the Selection Date populated";

                $ship_item->update_status( $SHIPMENT_ITEM_STATUS__SELECTED, $APPLICATION_OPERATOR_ID );
                my $log = $si_status_log->reset->first;
                $log->update( { date => $select_date } );

                # now the expected selection date can be specified
                $expected{selection_date}   = _format_date( $select_date );

                # get the list
                $list   = get_shipment_hold_list( $schema, $shipment->id );
                $row    = _find_shipment_in_hash( $list, $shipment->id, $channel_name, $test->{type} );
                ok( defined $row, "found the Shipment Id in the hash" );
                is_deeply( $row, \%expected, "the data for the shipment is as expected with the Selection Date" );

                # un-select the shipment item for the next loop round
                $ship_item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW } );
                $log->delete;
                $expected{selection_date} = '';
            }

            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}


#----------------------------------------------------------------------------------------------

# this goes through the HASH returned by 'get_shipment_hold_list'
# looking for a Shipment Id, if you give it a Sales Channel and Hold Type it
# will only look for shipments for that Sales Channel and that hold type
sub _find_shipment_in_hash {
    my ( $hash, $ship_id, $sales_channel, $hold_type )  = @_;

    my $row;

    foreach my $channel ( keys %{ $hash } ) {
        if ( defined $sales_channel ) {
            next    if ( $channel ne $sales_channel );
        }
        foreach my $type ( keys %{ $hash->{$channel} } ) {
            if ( defined $hold_type ) {
                next    if ( $type ne $hold_type );
            }

            # see if the shipment id exists in the hash
            if ( exists( $hash->{ $channel }{ $type }{ $ship_id } ) ) {
                $row    = $hash->{ $channel }{ $type }{ $ship_id };
                last;
            }
        }
        last    if ( defined $row );        # must have found something
    }

    return $row;
}

# this formats a date in the format expected from 'get_shipment_hold_list'
sub _format_date {
    my $date    = shift;
    return $date->dmy('-') . " " . sprintf( "%0.2d:%0.2d", $date->hour, $date->minute );
}

sub _create_test_order {

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
            how_many    => 2,
            channel     => Test::XTracker::Data->channel_for_nap,
            dont_ensure_stock => 1,
    } );

    my $base    = {
            shipping_charge => 10,
            create_renumerations => 1,
            currency_id => $CURRENCY__GBP,
            channel_id => $channel->id,
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        };

    my ( $order, $order_hash )  = Test::XTracker::Data->create_db_order( {
            pids => $pids,
            base => $base,
            attrs => [
                        { price => 100, tax => 10, duty => 20 },
                        { price => 200, tax => 20, duty => 30 },
                    ],
        } );

    # insert a shipment_item_status_log
    my $shipment    = $order->get_standard_class_shipment;
    $shipment->shipment_items
                ->first
                    ->update_status( $SHIPMENT_ITEM_STATUS__NEW, $APPLICATION_OPERATOR_ID );

    ok ($order, 'created order Id/Nr: '.$order->id.'/'.$order->order_nr);
    return $order;
}

