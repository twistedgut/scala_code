#!/usr/bin/perl
use NAP::policy "tt",     'test';

=head2 Cancelling a Pre Order/Pre Order Items

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :department
                                        :pre_order_status
                                        :pre_order_item_status
                                        :pre_order_refund_status
                                        :reservation_status
                                    );


# get a schema, sanity check
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");


#----------------------------------------------------------
_test_get_variants_for_pre_order( $schema, 1 );
_test_change_pre_order_item_size( $schema, 1 );
#----------------------------------------------------------

done_testing();

# test re-funding the Pre Order Payment
sub _test_get_variants_for_pre_order {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip '_test_get_variants_for_pre_order', 1      if ( !$oktodo );

        note "TESTING 'get_variants_for_pre_order' method";

        $schema->txn_do( sub {
            # create a couple of Pre-Orders using the same Variants as each other
            my $pre_order       = Test::XTracker::Data::PreOrder->create_complete_pre_order( { variants_per_product => 5 } );
            my $channel         = $pre_order->channel;
            my @variants        = map { $_->variant } $pre_order->pre_order_items->search( {}, { order_by => 'id' } )->all;
            my $othr_preorder   = Test::XTracker::Data::PreOrder->create_complete_pre_order( { variants => \@variants } );

            # get a Product to use and its Variants
            my $pre_ord_variant = $variants[2];             # this Variant will have 2 Pre-Orders against it
            my $product         = $pre_ord_variant->product;
            my @other_variants  = $product->variants->search( { id => { '!=' => $pre_ord_variant->id } } )->all;

            my @expected_variants   = map { $_->id } $product->variants->by_size_id->all;
            my $got = $product->get_variants_for_pre_order( $channel );
            isa_ok( $got, 'ARRAY', "'get_variants_for_pre_order' method returned" );
            isa_ok( $got->[0], 'HASH', "first element of Array" );
            my @got_variants        = map { $_->{variant}->id } @{ $got };
            is_deeply( \@got_variants, \@expected_variants, "got expected Variants and in the correct order" );

            # the level of Stock to use so that All
            # Variants have Stock Available or Unavailable
            my $available_stock_qty     = 5;
            my $unavailable_stock_qty   = 2;

            my %tests   = (
                    'All Variants have enough Stock to Pre-Order'   => {
                            available_variants  => [ $pre_ord_variant, @other_variants ],
                            expected_variants   => [ $pre_ord_variant, @other_variants ],
                        },
                    'One Variant does not have enough Stock to Pre-Order'   => {
                            available_variants  => [ @other_variants ],
                            unavailable_variants=> [ $pre_ord_variant ],
                            expected_variants   => [ $pre_ord_variant, @other_variants ],
                        },
                    'Exclude a Variant from the list that is returned'  => {
                            available_variants  => [ @other_variants ],
                            exclude_variant     => $pre_ord_variant,
                            expected_variants   => [ @other_variants ],
                        },
                );

            foreach my $label ( keys %tests ) {
                note "Test: $label";
                my $test    = $tests{ $label };

                _set_stock_ordered( $test->{available_variants}, $available_stock_qty );
                _set_stock_ordered( $test->{unavailable_variants}, $unavailable_stock_qty );

                my $args;
                if ( $test->{exclude_variant} ) {
                    $args->{exclude_variant_id} = $test->{exclude_variant}->id;
                }
                $got    = $product->get_variants_for_pre_order( $channel, $args );

                # check got expected variants
                my @expected_var_ids= sort { $a <=> $b } map { $_->id } @{ $test->{expected_variants} };
                my @got_var_ids     = sort { $a <=> $b } map { $_->{variant}->id } @{ $got };
                is_deeply( \@got_var_ids, \@expected_var_ids, "Returned Expected Variants" );

                # check got expected available flags
                my %expected_flags;
                $expected_flags{ $_->id }   = 1     foreach ( @{ $test->{available_variants} } );
                $expected_flags{ $_->id }   = 0     foreach ( @{ $test->{unavailable_variants} } );
                my %got_flags   = map { $_->{variant}->id => $_->{is_available} } @{ $got };
                is_deeply( \%got_flags, \%expected_flags, "Returned Expected 'is_available' Flags" );
            }


            # rollback any changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# tests changing the Size of a Pre-Order Item
# and it's associated Reservation
sub _test_change_pre_order_item_size {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip '_test_change_pre_order_item_size', 1      if ( !$oktodo );

        note "TESTING Pre-Order Item 'change_size_to' method";



        $schema->txn_do( sub {
            my $pre_order   = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
                                                                            product_quantity    => 5,
                                                                            variants_per_product=> 5,
                                                                        } );
            my $channel     = $pre_order->channel;
            my @items       = $pre_order->pre_order_items->order_by_id->all;
            my @reservations= map { $_->reservation } @items;
            my $new_item_rs = $pre_order->pre_order_items->order_by_id_desc;
            my $new_reservation_id_rs   = $schema->resultset('Public::Reservation')->get_column('id');

            # get a variant and a list of other sizes
            my $variant     = $items[0]->variant;
            my $product     = $variant->product;
            my @other_variants = $product->variants
                                        ->search( { id => { '!=' => $variant->id } } )
                                            ->all;

            # get other parameters to pass to the method
            my ( $stock_manager, $operator )    = _get_other_parameters( $schema, $channel );

            # check that Items without the correct Status of
            # 'Complete' should not allow you to change its size
            note "check Items with Incorrect Statuses should NOT allow a Size change";
            my $item_statuses   = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::PreOrderItemStatus', {
                                                                                                    allow => [ $PRE_ORDER_ITEM_STATUS__COMPLETE ],
                                                                                                } );
            my $allowed_status  = $item_statuses->{allowed}[0];

            foreach my $status ( @{ $item_statuses->{not_allowed} } ) {
                my $error_result    = {};
                $items[0]->update( { pre_order_item_status_id => $status->id } );
                ok( !defined $items[0]->change_size_to( $other_variants[0], $stock_manager, $operator->id, ),
                                                    "with Status: '" . $status->status . "' couldn't change Size, WITHOUT using an Error Result hash" );
                ok( !defined $items[0]->change_size_to( $other_variants[0], $stock_manager, $operator->id, $error_result ),
                                                    "with Status: '" . $status->status . "' couldn't change Size, WITH using an Error Result hash" );
                like( $error_result->{message}, qr/Pre-Order Item is NOT at the Correct Status/i,
                                                    "got Expected Error Message in the Error Result Hash" );
            }

            note "now test Changing Sizes";
            my %tests   = (
                    "Change Size with the Same Size, shouldn't do anything" => {
                            pre_order_item  => $items[0],
                            change_to_size  => $items[0]->variant,
                            have_enough_stock => 1,
                            expected_result => 0,
                            expected_err_msg=> qr/New Size is the Same as the Old/i,
                        },
                    "Change Size with New Size WITH enough Stock to Pre-Order with" => {
                            pre_order_item  => $items[1],
                            use_other_size  => 1,
                            have_enough_stock => 1,
                            expected_result => 'XTracker::Schema::Result::Public::PreOrderItem',
                        },
                    "Change Size with New Size WITHOUT enough Stock to Pre-Order with" => {
                            pre_order_item  => $items[2],
                            use_other_size  => 1,
                            have_enough_stock => 0,
                            expected_result => 0,
                            expected_err_msg=> qr/SOLD OUT of the New Size/i,
                        },
                    "Change Size with New Size that is for a different Product" => {
                            pre_order_item  => $items[3],
                            change_to_size  => $items[0]->variant,
                            have_enough_stock => 1,
                            expected_result => 0,
                            expected_err_msg=> qr/New Variant is NOT for the Same PID as the Old/i,
                        },
                );

            my $last_item_id        = $new_item_rs->reset->first->id;
            my $last_reservation_id = $new_reservation_id_rs->max;

            foreach my $label ( keys %tests ) {
                note "test: $label";
                my $test    = $tests{ $label };

                my $expected_result = $test->{expected_result};

                my $item    = $test->{pre_order_item}->discard_changes;
                $item->update( { pre_order_item_status_id => $allowed_status->id } );
                my $curr_variant    = $item->variant;
                my $new_variant     = $curr_variant->product->variants
                                                ->search( { id => { '!=' => $curr_variant->id } } )
                                                    ->first;
                $new_variant        = $test->{change_to_size}           if ( $test->{change_to_size} );

                my $set_stock_qty   = ( $test->{have_enough_stock} ? 100 : 0 );
                _set_stock_ordered( $new_variant, $set_stock_qty );

                my $error_result    = {};
                my $result  = $item->change_size_to( $new_variant, $stock_manager, $operator->id, $error_result );

                if ( $expected_result ) {
                    # Size was expected to have been changed
                    isa_ok( $result, $expected_result, "method returned Expected result" );

                    ok( !keys %{ $error_result }, "NO Error Result was set" )
                                                        or note "====> Error Result: " . p( $error_result );

                    cmp_ok( $item->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__CANCELLED,
                                                "Item Status is now 'Cancelled'" );
                    cmp_ok( $item->reservation->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                                                "Item's Reservation's Status is now 'Cancelled'" );

                    my $new_item    = $new_item_rs->reset->first;
                    cmp_ok( $new_item->id, '>', $last_item_id, "New Pre-Order Item Created" );
                    cmp_ok( $new_item->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__COMPLETE,
                                                    "New Item Status is 'Complete'" );
                    cmp_ok( $new_item->variant->id, '==', $new_variant->id, "and is for the new Variant" );
                    cmp_ok( $new_item->unit_price, '==', $item->unit_price, "Unit Price the Same" );
                    cmp_ok( $new_item->tax, '==', $item->tax, "Tax the Same" );
                    cmp_ok( $new_item->duty, '==', $item->duty, "Duty the Same" );

                    cmp_ok( $new_item->pre_order_item_status_logs->count, '==', 1, "Only 1 Item Status Log created for New Item" );
                    my $new_item_log= $new_item->pre_order_item_status_logs->first;
                    cmp_ok( $new_item_log->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__COMPLETE,
                                                    "Log's Status is 'Complete'" );
                    cmp_ok( $new_item_log->operator_id, '==', $operator->id, "Log's Operator Id is as Expected" );

                    my $new_reservation_id  = $new_reservation_id_rs->max;
                    cmp_ok( $new_reservation_id, '>', $last_reservation_id, "New Reservation Created" );
                    cmp_ok( $new_item->reservation_id, '==', $new_reservation_id, "and is Linked to the New Item" );
                    cmp_ok( $new_item->reservation->status_id, '==', $RESERVATION_STATUS__PENDING,
                                                    "New Reservation Status is 'Pending'" );
                    cmp_ok( $new_item->reservation->variant_id, '==', $new_variant->id, "and is also for the new Variant" );
                    cmp_ok( $new_item->reservation->ordering_id, '==', 0, "and it's 'ordering_id' field is ZERO" );

                    $last_item_id       = $new_item->id;
                    $last_reservation_id= $new_reservation_id;
                }
                else {
                    # Size was NOT expected to have been changed
                    ok( !defined $result, "method returned Expected 'undef'" );

                    ok( keys %{ $error_result }, "Error Result Hash was poulated" );
                    if ( $test->{expected_err_msg} ) {
                        like( $error_result->{message}, $test->{expected_err_msg}, "and with Expected Error Message" );
                    }

                    cmp_ok( $item->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__COMPLETE,
                                                "Item Status is STILL 'Complete'" );
                    cmp_ok( $item->reservation->status_id, '==', $RESERVATION_STATUS__PENDING,
                                                "Item's Reservation's Status is STILL 'Pending'" );
                    cmp_ok( $last_item_id, '==', $new_item_rs->reset->first->id, "NO New Item Created" );
                    cmp_ok( $last_reservation_id, '==', $new_reservation_id_rs->max, "NO New Reservation Created" );
                }
            }


            # rollback any changes
            $schema->txn_rollback();
        } );
    };

    return;
}

#---------------------------------------------------------------------------------------------

# will set the Stock Ordered Qty for all
# Variants on the 'stock_order_item' records
sub _set_stock_ordered {
    my ( $variants, $qty )  = @_;

    return      if ( !$variants );

    $variants   = ( ref( $variants ) eq 'ARRAY' ? $variants : [ $variants ] );

    foreach my $variant ( @{ $variants } ) {
        $variant->stock_order_items->update( {
                                        quantity            => $qty,
                                        original_quantity   => $qty,
                                    } );
    }

    return;
}

# get Stock Manager & Operator
sub _get_other_parameters {
    my ( $schema, $channel )    = @_;

    my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                schema      => $schema,
                                                                channel_id  => $channel->id,
                                                            } );
    my $operator        = $schema->resultset('Public::Operator')->search( {
                                                            id              => { '!=' => $APPLICATION_OPERATOR_ID },
                                                            username        => { '!=' => 'it.god' },
                                                            department_id   => { '!=' => undef },
                                                    } )->first;

    return ( $stock_manager, $operator );
}
