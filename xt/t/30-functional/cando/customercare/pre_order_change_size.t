#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 NAME

pre_order_change_size.t - Test Changeing Sizes of Pre-Order Items

=head1 DESCRIPTION

Tests Changing the Size of Pre-Order Items from the Pre-Order Summary page.

#TAGS inventory preorder cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::PSP;
use Test::XT::Flow;

use XTracker::Database::Reservation     qw( get_from_email_address );
use XTracker::Utilities                 qw( format_currency_2dp );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :correspondence_templates
                                            :pre_order_status
                                            :pre_order_item_status
                                            :reservation_status
                                        );

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Reservations',
    ],
);

#---------- run tests ----------
_test_when_can_use_functionality( $framework, 1 );
_test_change_size( $framework, 1 );
#-------------------------------

done_testing();

=head1 METHODS

=head2 _test_change_size

    _test_change_size( $framework, $ok_to_do_flag );

Test Changing Pre-Order Item Sizes.

=cut

sub _test_change_size {
    my ( $framework, $oktodo )  = @_;

    SKIP: {
        skip "_test_pre_order_summary_page", 1      if ( !$oktodo );

        note "TESTING 'Change Pre-Order Item Sizes' page";

        # 'set_department' should return the Operator Record of the user it's updating
        my $itgod_op    = Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                    'Stock Control/Reservation',
                ]
            }
        } );

        my $pre_order       = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
                                                                                product_quantity        => 5,
                                                                                variants_per_product    => 5,
                                                                        } );
        my $pre_order_id    = $pre_order->id;
        my $max_item_rs     = $pre_order->pre_order_items->get_column('id');
        my $max_item_id     = $max_item_rs->max;
        my $pre_ord_email_rs= $pre_order->pre_order_email_logs;
        my @pre_order_items = $pre_order->pre_order_items->order_by_id->all;
        my $mech            = $framework->mech;

        # set the Customer's Language to be 'French' which should
        # mean the Email From address should be localised
        $pre_order->customer->set_language_preference('fr');

        # clear out any emails logged
        $pre_ord_email_rs->delete;

        # get alternative sizes to change to for each Item's Variant
        my @variants_used   = map { $_->variant } @pre_order_items;
        my @alt_variants;
        foreach my $variant ( @variants_used ) {
            my @variants    = $variant->product->variants
                                        ->search( { id => { '!=' => $variant->id } } )
                                            ->by_size_id->all;
            push @alt_variants, \@variants;
        }

        # make some Variants out of Stock
        _set_stock_ordered( [ @{ $alt_variants[2] }[1,3] ], 0 );
        _set_stock_ordered( [ @{ $alt_variants[4] }[0,2] ], 0 );

        $framework->mech__reservation__pre_order_summary( $pre_order_id )
                    ->mech__reservation__pre_order_click_change_item_size;

        # check that those that are out of stock are flagged as such
        _check_sold_out_variants_for_item( $mech, $pre_order_items[2], [ @{ $alt_variants[2] }[1,3] ] );
        _check_sold_out_variants_for_item( $mech, $pre_order_items[4], [ @{ $alt_variants[4] }[0,2] ] );

        $mech->errors_are_fatal(0);

        note "select NO items should see warning";
        $framework->mech__reservation__pre_order_change_item_size_submit( { $pre_order_items[0]->id => 0 } );
        like( $mech->app_error_message, qr/You haven't chosen any New Sizes/i,
                                            "Found 'No New Sizes' warning message" );

        note "select ONLY Sold Out Sizes and should see warning";
        $framework->mech__reservation__pre_order_change_item_size_submit( {
                                                        $pre_order_items[2]->id => $alt_variants[2][3]->id,
                                                        $pre_order_items[4]->id => $alt_variants[4][0]->id,
                                                    } );
        like( $mech->app_error_message, qr/SOLD OUT of the New Size/i,
                                            "Found 'Sold Out Sizes' warning message" );

        $mech->errors_are_fatal(1);

        note "change some Sizes";
        $framework->mech__reservation__pre_order_change_item_size_submit( {
                                                        $pre_order_items[0]->id => $alt_variants[0][1]->id,
                                                        $pre_order_items[1]->id => $alt_variants[1][2]->id,
                                                    } );
        like( $mech->app_status_message, qr/Changes have been Successfully made/i,
                                            "Found 'Sizes Changed' status message" );
        _check_size_has_changed( $mech, $max_item_id, $pre_order_items[0], $alt_variants[0][1] );
        _check_size_has_changed( $mech, $max_item_id, $pre_order_items[1], $alt_variants[1][2] );
        $max_item_id    = $max_item_rs->reset->max;
        _check_for_email_form_in_page( $mech, $pre_order, $itgod_op );

        $framework->mech__reservation__pre_order_change_item_size_send_email();
        like( $mech->app_status_message, qr/Email has been Sent/i, "Found 'Email Sent' Status Message" );
        my $email_log   = $pre_ord_email_rs->reset->first;
        isa_ok( $email_log, 'XTracker::Schema::Result::Public::PreOrderEmailLog',
                                "An Email has been Logged" );
        cmp_ok( $email_log->correspondence_templates_id, '==', $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__SIZE_CHANGE,
                                "and is for the Expected Template Id: " . $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__SIZE_CHANGE );
        cmp_ok( $email_log->operator_id, '==', $itgod_op->id, "with the Expected Operator Id: " . $itgod_op->id );

        note "change some Sizes but have some fail because of Stock Level or incorrect Status";

        $framework->mech__reservation__pre_order_summary( $pre_order_id )
                    ->mech__reservation__pre_order_click_change_item_size;

        _discard_changes( @pre_order_items );
        $pre_ord_email_rs->reset->delete;
        $mech->errors_are_fatal(0);

        # clear out Stock for one
        _set_stock_ordered( [ @{ $alt_variants[2] }[0] ], 0 );
        # set another Item to be Exported
        $pre_order_items[3]->update( { pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__EXPORTED } );

        $framework->mech__reservation__pre_order_change_item_size_submit( {
                                                        $pre_order_items[2]->id => $alt_variants[2][0]->id,     # shouldn't get changed
                                                        $pre_order_items[3]->id => $alt_variants[3][2]->id,     # shouldn't get changed
                                                        $pre_order_items[4]->id => $alt_variants[4][1]->id,     # should be fine
                                                    } );
        like( $mech->app_status_message, qr/Changes have been Successfully made/i,
                                            "Found 'Sizes Changed' status message" );
        like( $mech->app_error_message, qr/Items couldn't be Changed/i,
                                            "Found 'Sizes Couldn't be Changed' warning message" );
        _discard_changes( $pre_order, @pre_order_items );
        _check_size_has_changed( $mech, $max_item_id, $pre_order_items[4], $alt_variants[4][1] );
        cmp_ok( $pre_order_items[2]->is_complete, '==', 1,
                                "Item: " . $pre_order_items[2]->id . "/" . $pre_order_items[2]->variant->sku . " wasn't Changed" );
        cmp_ok( $pre_order_items[3]->is_exported, '==', 1,
                                "Item: " . $pre_order_items[3]->id . "/" . $pre_order_items[3]->variant->sku . " is Still Exported" );
        cmp_ok( $pre_order->pre_order_items->search( { id => { '>' => $max_item_id } } )->count, '==', 1,
                                "Only 1 New Item has been Created for the Pre-Order" );
        _check_for_email_form_in_page( $mech, $pre_order, $itgod_op );

        $mech->errors_are_fatal(1);

        $framework->mech__reservation__pre_order_change_item_size_skip_email();
        like( $mech->app_info_message, qr/Did Not Send an Email/i, "Found: 'Did Not Send an Email' message" );
        cmp_ok( $pre_ord_email_rs->reset->count(), '==', 0, "and an Email was Not Logged as being Sent" );
    };

    return $framework;
}

=head2 _test_when_can_use_functionality

    _test_when_can_use_functionality( $framework, $ok_to_do_flag );

Checks when a user should be-able to see the Change Size link on the Pre-Order Summary page
and when they are able to select an item to change. This depends on the different Statuses
the Pre-Order & Pre-Order Items are set to.

=cut

sub _test_when_can_use_functionality {
    my ( $framework, $oktodo )  = @_;

    SKIP: {
        skip "_test_when_can_see_link", 1       if ( !$oktodo );

        note "TESTING When a User Can & Can't see the Change Size link";

        Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Stock Control/Reservation',
                ]
            }
        } );
        my $pre_order       = Test::XTracker::Data::PreOrder->create_complete_pre_order();
        my $mech            = $framework->mech;

        # check only Allowed Pre-Order Statuses can see the Size Change link
        my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::PreOrderStatus', {
                                                                                        allow   => [
                                                                                                    $PRE_ORDER_STATUS__COMPLETE,
                                                                                                    $PRE_ORDER_STATUS__PART_EXPORTED,
                                                                                                ],
                                                                                    } );

        note "check NOT Allowed Pre-Order Statuses can NOT see the Change Size link";
        foreach my $status ( @{ $statuses->{not_allowed} } ) {
            $pre_order->discard_changes->update( { pre_order_status_id => $status->id } );
            $framework->mech__reservation__pre_order_summary( $pre_order->id );
            my $pg_data = $mech->as_data();
            ok( !exists( $pg_data->{change_size_link} ), "Status: '" . $status->status . "', does NOT have the link" );
        }

        note "check ALLOWED Pre-Order Statuses CAN see the Change Size link";
        foreach my $status ( @{ $statuses->{allowed} } ) {
            $pre_order->discard_changes->update( { pre_order_status_id => $status->id } );
            $framework->mech__reservation__pre_order_summary( $pre_order->id );
            my $pg_data = $mech->as_data();
            like( $pg_data->{change_size_link}{value}, qr/Change Sizes for Pre-Order Items/i,
                                    "Status: '" . $status->status . "', CAN see the link" );
        }


        # check only Allowed Pre-Order Statuses can see the Size Change link
        $statuses   = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::PreOrderItemStatus', {
                                                                                        allow   => [
                                                                                                    $PRE_ORDER_ITEM_STATUS__COMPLETE,
                                                                                                ],
                                                                                        exclude => [
                                                                                                    $PRE_ORDER_ITEM_STATUS__CANCELLED,
                                                                                                ],
                                                                                    } );

        note "check NOT Allowed Pre-Order Item Statuses can NOT be Selected to be Changed";
        foreach my $status ( @{ $statuses->{not_allowed} } ) {
            my $status_name = $status->status;
            $pre_order->discard_changes
                        ->pre_order_items->update( { pre_order_item_status_id => $status->id } );

            $framework->mech__reservation__pre_order_summary( $pre_order->id )
                        ->mech__reservation__pre_order_click_change_item_size;

            my $pg_data = $mech->as_data()->{item_list};
            like( $pg_data->[0]{'Select Item'}, qr/$status_name/i,
                                "Status: '" . $status->status . "', does NOT have the 'Select' Check Box but shows the Status instead" );
        }

        note "check ALLOWED Pre-Order Item Statuses CAN be Selected to be Changed";
        foreach my $status ( @{ $statuses->{allowed} } ) {
            $pre_order->discard_changes
                        ->pre_order_items->update( { pre_order_item_status_id => $status->id } );

            $framework->mech__reservation__pre_order_summary( $pre_order->id )
                        ->mech__reservation__pre_order_click_change_item_size;

            my $pg_data = $mech->as_data()->{item_list};
            like( $pg_data->[0]{'Select Item'}{input_name}, qr/pre_order_item-\d+/,
                                            "Status: '" . $status->status . "', DOES have the 'Select' Check Box" );
        }
    };

    return $framework;
}

#-----------------------------------------------------------------

=head2 _check_sold_out_variants_for_item

    _check_sold_out_variants_for_item( $mech_object, $dbic_pre_order_item, $dbic_variants_array_ref );

Test Helper that checks Alternative Variants for an Item have been flagged as 'SOLD OUT' on the page.

=cut

sub _check_sold_out_variants_for_item {
    my ( $mech, $item, $variants )  = @_;

    note "checking 'SOLD OUT' Alternative Variants for Item: " . $item->id . " / " . $item->variant->sku;
    my $item_list   = $mech->as_data()->{item_list};

    # get the Item in the list to check on
    my ( $item_row )    = grep { $_->{SKU} eq $item->variant->sku }
                                @{ $item_list };
    ok( defined $item_row, "Found Row for Item" );
    my @alt_variants    = @{ $item_row->{'Change To'}{select_values} };
    shift @alt_variants;    # get rid of the first 2 elements
    shift @alt_variants;    # which are just descriptive

    foreach my $variant ( @{ $variants } ) {
        my $to_match    = $variant->sku . " .*SOLD OUT";
        ok( grep( { $_->[1] =~ m/$to_match/i } @alt_variants ),
                        "Found 'SOLD OUT' SKU: " . $variant->sku . " in list of Alternative Variants" );
    }

    return;
}

=head2 _check_size_has_changed

    _check_size_has_changed(
        $mech_object,
        $prev_max_item_id,
        $dbic_pre_order_item,
        $dbic_new_size,
    );

Test Helper that checks that sizes have been changed properly.

=cut

sub _check_size_has_changed {
    my ( $mech, $prev_max_item_id, $item, $new_size )   = @_;

    note "checking Item: " . $item->discard_changes->id . " has Changed Size from " . $item->variant->sku . " to " . $new_size->sku;

    my $pre_order   = $item->pre_order;

    cmp_ok( $item->is_cancelled, '==', 1, "Original Item has been 'Cancelled'" );
    cmp_ok( $item->reservation->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                                    "Item's Reservation has been 'Cancelled'" );

    # search for all the Items for the same PID as $item
    my $new_item    = $pre_order->pre_order_items->search( {
                                                'variant.product_id' => $item->variant->product_id,
                                            },
                                            {
                                                join => 'variant',
                                            } )
                                            ->order_by_id_desc->first;
    cmp_ok( $new_item->id, '>', $prev_max_item_id, "New Item has been Created: " . $new_item->id );
    cmp_ok( $new_item->variant_id, '==', $new_size->id, "New Item is for the New Size" );
    cmp_ok( $new_item->is_complete, '==', 1, "New Item's Status is 'Complete'" );
    cmp_ok( $new_item->reservation->status_id, '==', $RESERVATION_STATUS__PENDING,
                                    "New Item's Reservation Status is 'Pending'" );
    cmp_ok( $new_item->reservation->ordering_id, '==', 0,
                                    "New Item's Reservation 'ordering_id' is ZERO" );

    # find the changed item in the page
    my $item_list   = $mech->as_data()->{item_list};
    my ( $row ) = grep { $_->{SKU} eq $item->variant->sku } @{ $item_list };
    is( ref( $row ), 'HASH', "Found Row on page for the Changed SKU: " . $item->variant->sku );
    is( $row->{'New SKU'}, $new_size->sku, "and the 'New SKU' is as Expected: " . $new_size->sku );

    return;
}

=head2 _check_for_email_form_in_page

    _check_for_email_form_in_page( $mech_object );

Test Helper that checks the Email Form is on the page.

Setting the environment variable 'HARNESS_VERBOSE' to '1' before running
this test will cause this function to show the contents of the Email to
the screen to aid in debugging.

=cut

sub _check_for_email_form_in_page {
    my ( $mech, $pre_order, $operator ) = @_;

    my $expected_from_address   = get_from_email_address( {
        channel_config  => $pre_order->channel->business->config_section,
        department_id   => $operator->department_id,
        schema          => $pre_order->result_source->schema,
        locale          => $pre_order->customer->locale,
    } );

    my $email_form  = $mech->as_data()->{email_form};
    is( ref( $email_form ), 'HASH', "Found Email Form in page" );
    cmp_ok( $email_form->{hidden_fields}{template_id}, '==', $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__SIZE_CHANGE,
                                "Found the Pre-Order Size Change Email Template Id in the Email Form" );
    is( $email_form->{To}, $pre_order->customer->email, "and Email To is as expected: '" . $pre_order->customer->email . "'" );
    is( $email_form->{From}, $expected_from_address, "and Email From is as expected: '${expected_from_address}'" );
    is( $email_form->{'Reply-To'}, $expected_from_address, "and Email Reply-To is as expected: '${expected_from_address}'" );
    cmp_ok( length( $email_form->{'Subject'} ), '>', 5, "and Email Subject has some text in it" );
    cmp_ok( length( $email_form->{'Email Text'} ), '>', 30, "and Email Content has some text in it" );
    cmp_ok( length( $email_form->{hidden_fields}{email_content_type} ), '>', 2, "and Email Content Type has a value" );

    if ( $ENV{'HARNESS_VERBOSE'} ) {
        # get the text out of the page, $mech->as_data takes all the newlines out
        my ( $textarea )    = $mech->find_all_inputs( type => 'textarea', name => 'email_content' );
        # show the content for visual checks
        diag "=================================";
        diag $textarea->value;
        diag "---------------------------------";
    }

    return;
}

=head2 _discard_changes

    _discard_changes( @dbic_recs );

Discard_changes for an array of records.

=cut

sub _discard_changes {
    my @recs    = @_;

    foreach my $rec ( @recs ) {
        $rec->discard_changes;
    }

    return;
}

=head2 _set_stock_ordered

    _set_stock_ordered( $dbic_variants_array_ref, $quantity_to_set_them_to );

Change the Stock Quantity for variants.

=cut

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

