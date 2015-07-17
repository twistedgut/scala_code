#!/usr/bin/env perl


use NAP::policy "tt",     'test';

use parent "NAP::Test::Class";

=head1

This tests the various scenarios when calling the 'split_if_needed' method on a Return
and also the 'split_me' method on a Renumeration. This includes making sure 'Passed QC'
items are split off onto a new Renumeration and also 'Failed QC' items, also makes
sure that items are only split off from a Renumeration when they need to be.

=cut

use Test::XTracker::Data;
use XTracker::WebContent::StockManagement;

use XTracker::Config::Local         qw( config_var config_section_slurp );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_issue_type
                                        :renumeration_class
                                        :renumeration_status
                                        :renumeration_type
                                        :return_item_status
                                        :shipment_class
                                        :shipment_status
                                        :shipment_item_status
                                    );

use List::Util                      qw( sum );


# this is done once, when the test starts
sub startup : Test( startup => 1 ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{channel}= Test::XTracker::Data->any_channel;
    $self->{domain} = Test::XTracker::Data->returns_domain_using_dump_dir();
    $self->{stock_manager} = XTracker::WebContent::StockManagement->new_stock_manager( {
        schema     => $self->schema,
        channel_id => $self->{channel}->id,
    } );

    $self->{return_item_status_map} = {
        'Booked In'         => $RETURN_ITEM_STATUS__BOOKED_IN,
        'Passed QC'         => $RETURN_ITEM_STATUS__PASSED_QC,
        'Failed QC'         => $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
        'Failed QC Accepted'=> $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED,
        'Failed QC Rejected'=> $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED,
        'Put Away'          => $RETURN_ITEM_STATUS__PUT_AWAY,
        'Cancelled'         => $RETURN_ITEM_STATUS__CANCELLED,
    };
}

# done everytime before each Test method is run
sub setup: Test( setup => 1 ) {
    my $self = shift;
    $self->SUPER::setup;

    # Start a transaction, so we can rollback after testing
    $self->schema->txn_begin;

    my $num_pids    = 5;
    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
        how_many    => $num_pids,
        channel     => $self->{channel},
    } );

    my @attrs       = map { { price => ( 100 + ( $_ * 10 ) ), tax => 0, duty => 0 } } 1..$num_pids;
    my $total_price = 0.00;
    $total_price    += $_->{price}      foreach ( @attrs );

    my $base    = {
        shipping_charge => 10.00,
        tenders         => [ { type => 'card_debit', value => 10 + $total_price } ],
    };

    my ( $order, $order_hash )  = Test::XTracker::Data->create_db_order( {
            pids => $pids,
            base => $base,
            attrs=> \@attrs,
        } );

    my $shipment    = $order->get_standard_class_shipment;
    my @items       = $shipment->shipment_items->search( {}, { order_by => 'id' } )->all;

    note "Creating a Return";
    my %items_to_return = map { $_->id => { type => 'Return', reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL } } @items;
    $self->_create_return( $shipment, \%items_to_return );

    $self->{shipment}       = $shipment->discard_changes;
    $self->{shipment_items} = \@items;
}

# done everytime after each Test method has run
sub teardown: Test(teardown) {
    my $self    = shift;
    $self->SUPER::teardown;

    # rollback changes done in a test
    # so they don't affect the next test
    $self->schema->txn_rollback;

    # remove any Exchange Shipments from the stash
    delete $self->{exchange_shipment};
}


=head1 TEST METHODS

=head2 Test Splitting off of Shipping Charges and/or Refunds

Tests that when an Invoice is split which has any Refund or Shipping Charges that they are
put on the new invoice and not left on the old.

The following methods test this:

    * test_split_off_of_both_shipping_charge_and_refund - test when both columns have values
    * test_split_off_of_just_shipping_charge            - test when only Shipping Charge has a value
    * test_split_off_of_just_shipping_refund            - test when only Shipping Refund has a value

The fields should only be copied when passed in 'Passed QC' items and NOT for 'Failed QC' items.

=cut

sub test_split_off_of_both_shipping_charge_and_refund : Tests() {
    my $self    = shift;

    note "Test Using Shipping Charge of: '-10', and Shipping Refund of: '7'";
    $self->_spliting_off_of_shipping_charge_and_refund( -10, 7 );
}

sub test_split_off_of_just_shipping_charge : Tests() {
    my $self    = shift;

    note "Test Using Shipping Charge of: '-10', and Shipping Refund of: '0'";
    $self->_spliting_off_of_shipping_charge_and_refund( -10, 0 );
}

sub test_split_off_of_just_shipping_refund : Tests() {
    my $self    = shift;

    note "Test Using Shipping Charge of: '0', and Shipping Refund of: '7'";
    $self->_spliting_off_of_shipping_charge_and_refund( 0, 7 );
}

# helper used for the above Shipping Charge/Refund tests
sub _spliting_off_of_shipping_charge_and_refund {
    my ( $self, $shipping_charge, $shipping_refund )    = @_;

    my $return  = $self->{return};

    # set Shipping & Charges that should end up on the
    # new Renumeration and zeroed on the original
    my $renumeration_orig   = $self->{renumeration};
    $shipping_refund    = _d3( $shipping_refund );
    $shipping_charge    = _d3( $shipping_charge );
    $renumeration_orig->update( { shipping => $shipping_refund, misc_refund => $shipping_charge } );

    # Pass QC two of the Items individually
    my $pass_qc_rs_1= $self->_pass_qc_items( @{ $self->{return_items} }[0] );
    my $pass_qc_rs_2= $self->_pass_qc_items( @{ $self->{return_items} }[1] );
    # Fail QC two of the other Items
    my $fail_qc_rs  = $self->_fail_qc_items( @{ $self->{return_items} }[2,3] );

    note "Split off Two Failed QC Items onto a another new Renumeration, 'shipping' and 'misc_refund' values should NOT be copied";
    $renumeration_orig->split_me( $fail_qc_rs );
    my $renumeration_new    = $self->{renumeration_rs}->reset->first;
    cmp_ok( $renumeration_new->id, '>', $renumeration_orig->id, "NEW Renumeration record created" );
    cmp_ok( _d3( $renumeration_new->shipping ), '==', 0.000,
                                "Shipping Refund ('shipping' column) on Latest Renumeration is 0.000" );
    cmp_ok( _d3( $renumeration_new->misc_refund ), '==', 0.000,
                                "Shipping Charge ('misc_refund' column) on Latest Renumeration is 0.000" );
    cmp_ok( $renumeration_new->renumeration_items->count, '==', 2, "New Renumeration has 2 Renumeration Items" );
    cmp_ok( $renumeration_orig->renumeration_items->count, '==', 3, "Original Renumeration now has 3 Renumeration Item" );
    my $old_id  = $renumeration_new->id;


    note "Split off a Passed QC Item onto a seperate Renumeration, 'shipping' and 'misc_refund' values SHOULD be copied";
    $renumeration_orig->split_me( $pass_qc_rs_1 );
    $renumeration_new   = $self->{renumeration_rs}->reset->first;
    cmp_ok( $renumeration_new->id, '>', $old_id, "NEW Renumeration record created" );
    cmp_ok( _d3( $renumeration_new->shipping ), '==', $shipping_refund,
                                "Shipping Refund ('shipping' column) appearing on NEW Renumeration" );
    cmp_ok( _d3( $renumeration_new->misc_refund ), '==', $shipping_charge,
                                "Shipping Charge ('misc_refund' column) appearing on NEW Renumeration" );
    cmp_ok( $renumeration_new->renumeration_items->count, '==', 1, "New Renumeration has 1 Renumeration Item" );
    cmp_ok( _d3( $renumeration_orig->shipping ), '==', 0.000,
                                "Shipping Refund ('shipping' column) on Original Renumeration is 0.000" );
    cmp_ok( _d3( $renumeration_orig->misc_refund ), '==', 0.000,
                                "Shipping Charge ('misc_refund' column) on Original Renumeration is 0.000" );
    cmp_ok( $renumeration_orig->renumeration_items->count, '==', 2, "Original Renumeration now has 2 Renumeration Items" );
    $old_id = $renumeration_new->id;


    # now test that another split with a Passed QC item DOESN'T also copy those original values accross

    note "Split off another Passed QC Item onto a seperate Renumeration, 'shipping' and 'misc_refund' values SHOULD be ZERO";
    $renumeration_orig->split_me( $pass_qc_rs_2 );
    $renumeration_new   = $self->{renumeration_rs}->reset->first;
    cmp_ok( $renumeration_new->id, '>', $old_id, "NEW Renumeration record created" );
    cmp_ok( _d3( $renumeration_new->shipping ), '==', 0.000,
                                "Shipping Refund ('shipping' column) on Latest Renumeration is 0.000" );
    cmp_ok( _d3( $renumeration_new->misc_refund ), '==', 0.000,
                                "Shipping Charge ('misc_refund' column) on Latest Renumeration is 0.000" );
    cmp_ok( $renumeration_new->renumeration_items->count, '==', 1, "New Renumeration has 1 Renumeration Item" );
    cmp_ok( $renumeration_orig->renumeration_items->count, '==', 1, "Original Renumeration now has only 1 Renumeration Item" );
}

=head2 test_split_me

This tests the 'split_me' method on the 'Public::Renumeration' class.

=cut

sub test_split_me : Tests() {
    my $self    = shift;

    my $renumeration= $self->{renumeration};
    my $return      = $self->{return};

    # test that a Renumeration can only be in certain
    # Statuses to allow items to be Split Off it
    my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::RenumerationStatus', {
        allow => [
            $RENUMERATION_STATUS__PENDING,
            $RENUMERATION_STATUS__AWAITING_AUTHORISATION,
        ],
    } );
    # get a Result Set of just one item
    my $item_rs = $return->return_items->search( { id => $self->{return_items}[0]->id } );
    my $num_items_on_renumeration   = $renumeration->renumeration_items->count;

    note "Testing Renumeration Statuses that SHOULDN'T allow any Splits";
    foreach my $status ( @{ $statuses->{not_allowed} } ) {
        $renumeration->update( { renumeration_status_id => $status->id } );
        $renumeration->split_me( $item_rs->reset );
        cmp_ok(
            $renumeration->discard_changes->renumeration_items->count,
            '==',
            $num_items_on_renumeration,
            "With Status: '" . $status->status . "' NO Items were Split Off from the Renumeration"
        );
    }

    note "Testing Renumeration Statuses that SHOULD allow Splits";
    foreach my $status ( @{ $statuses->{allowed} } ) {
        $renumeration->update( { renumeration_status_id => $status->id } );
        $renumeration->split_me( $item_rs->reset );
        cmp_ok(
            $renumeration->discard_changes->renumeration_items->count,
            '==',
            ( $num_items_on_renumeration - 1 ),
            "With Status: '" . $status->status . "' ONE Item was Split Off from the Renumeration"
        );
        $self->_reset_data;
    }


    # both Renumeration and Return Items are sorted
    # by Shipment Item Id and so share the array Index
    my @renum_items     = @{ $self->{renum_items} };
    my @return_items    = @{ $self->{return_items} };

    # before tests, move some of the Renumeration Items off
    # the existing Renumeration so as to use them in tests
    # where items not on the renumeration are required
    my $another_renum   = $self->_create_renumeration();
    $renum_items[0]->update( { renumeration_id => $another_renum->id } );
    $renum_items[1]->update( { renumeration_id => $another_renum->id } );
    my @return_items_not_on_renum   = ( @return_items[0,1] );
    my @return_items_on_renum       = ( @return_items[2..4] );
    my %shipment_item_ids_on_renum  = map { $_->shipment_item_id => 1 } @return_items_on_renum;

    # this returns ALL renumerations for the Return
    my $renumeration_rs = $self->{renumeration_rs};

    # make sure the 'another_renum' is excluded
    # from the new renumerations result set
    my $new_renum_rs = $self->{new_renum_rs} = $self->{new_renum_rs}->search( {
        id => { '!=' => $another_renum->id },
    } );

    my %tests   = (
        "Split off One Item"    => {
            setup   => {
                items_to_split  => [ $return_items_on_renum[0] ],
            },
            expected=> {
                items_split_off => [ $return_items_on_renum[0] ],
                number_of_renumerations_after   => 3,
            },
        },
        "Split off Two Items"   => {
            setup   => {
                items_to_split  => [ @return_items_on_renum[0,1] ],
            },
            expected=> {
                items_split_off => [ @return_items_on_renum[0,1] ],
                number_of_renumerations_after   => 3,
            },
        },
        "Split off ALL Items on the Renumeration, then nothing should be split off"   => {
            setup   => {
                items_to_split  => [ @return_items_on_renum ],
            },
            expected=> {
                items_split_off => [ ],
                number_of_renumerations_after   => 2,
            },
        },
        "Ask to Split off Two items one of which is not on the Renumeration, should get a new Renumeration with 1 item" => {
            setup   => {
                items_to_split  => [ $return_items_on_renum[1], $return_items_not_on_renum[0] ],
            },
            expected=> {
                items_split_off => [ $return_items_on_renum[1] ],
                number_of_renumerations_after   => 3,
            },
        },
        "Ask to Split off 5 items which include 2 NOT ON the Renumeration and the other 3 are the ONLY items on the Renumeration" => {
            setup   => {
                items_to_split  => [ @return_items_on_renum, @return_items_not_on_renum ],
            },
            expected=> {
                items_split_off => [ ],
                number_of_renumerations_after   => 2,
            },
        },
        "Ask to Split off 3 items which include 1 NOT ON the Renumeration and 2 that are, should get a new Renumeration with 2 items" => {
            setup   => {
                items_to_split  => [ @return_items_on_renum[1,2], $return_items_not_on_renum[1] ],
            },
            expected=> {
                items_split_off => [ @return_items_on_renum[1,2] ],
                number_of_renumerations_after   => 3,
            },
        },
        "Ask to Split off 2 items NONE of which are on the Renumeration, no new Renumeration should be created" => {
            setup   => {
                items_to_split  => [ @return_items_not_on_renum ],
            },
            expected=> {
                items_split_off => [ ],
                number_of_renumerations_after   => 2,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expected= $test->{expected};

        $self->_reset_data;
        $renumeration->discard_changes;

        # build up data for the Return Items used in the test
        my @id_list     = map { $_->id } @{ $setup->{items_to_split} };

        # work out the Renumeration Totals
        my $current_renum_total = $renumeration->grand_total;
        my $new_renum_total     = sum( 0, map {
            $_->shipment_item->unit_price
            + $_->shipment_item->tax
            + $_->shipment_item->duty
        } grep { exists( $shipment_item_ids_on_renum{ $_->shipment_item_id } ) }
            @{ $setup->{items_to_split} } );
        my $current_renum_new_total = $current_renum_total - $new_renum_total;

        # build a Return Item Result Set to be passed to the method
        my $return_item_rs  = $return->return_items->search( {
            id  => { IN => \@id_list },
        } );

        # Call the method
        $renumeration->split_me( $return_item_rs );

        $renumeration->discard_changes;
        cmp_ok( $renumeration_rs->reset->count, '==', $expected->{number_of_renumerations_after},
                    "Total number of Renumeration records now created as expected: " . $expected->{number_of_renumerations_after} );

        # if there is expected to be items on a new Renumeration then check them
        if ( @{ $expected->{items_split_off} } ) {
            my ( $new_renum_rec )   = $new_renum_rs->reset->all;
            isa_ok( $new_renum_rec, 'XTracker::Schema::Result::Public::Renumeration', "New Renumeration Record has been created" );
            is_deeply(
                [ sort { $a <=> $b } map { $_->shipment_item_id } $new_renum_rec->renumeration_items->all ],
                [ sort { $a <=> $b } map { $_->shipment_item_id } @{ $expected->{items_split_off} } ],
                "Checking Renumeration: " . $new_renum_rec->id . ", for items and got all expected"
            );

            cmp_ok( $new_renum_rec->link_return_renumerations->first->return_id, '==', $return->id,
                        "Renumeration's 'link_return_renumeration' record is for the Correct Return Id: " . $return->id );

            # check the Existing Renumeration and it's Renumeration Tenders
            cmp_ok( _d3( $renumeration->grand_total ), '==', _d3( $current_renum_new_total ),
                            "Existing Renumeration Total has now been reduced to: " . _d3( $current_renum_new_total ) );
            cmp_ok( _d3( $renumeration->renumeration_tenders->get_column('value')->sum ), '==', _d3( $current_renum_new_total ),
                            "Existing Renumeration's Renumeration Tenders Total as Expected: " . _d3( $current_renum_new_total ) );

            # check the New Renumeration and it's Renumeration Tenders
            cmp_ok( _d3( $new_renum_rec->grand_total ), '==', _d3( $new_renum_total ),
                            "New Renumeration Total is as Expected: " . _d3( $new_renum_total ) );
            cmp_ok( _d3( $new_renum_rec->renumeration_tenders->get_column('value')->sum ), '==', _d3( $new_renum_total ),
                            "New Renumeration's Renumeration Tenders Total as Expected: " . _d3( $new_renum_total ) );
        }
        else {
            cmp_ok( $new_renum_rs->reset->count, '==', 0, "NO New Renumerations have been created" );

            # check the Existing Renumeration and it's Renumeration Tenders haven't changed
            cmp_ok( _d3( $renumeration->grand_total ), '==', _d3( $current_renum_total ), "Existing Renumeration Total remains Unchanged" );
            cmp_ok( _d3( $renumeration->renumeration_tenders->get_column('value')->sum ), '==', _d3( $current_renum_total ),
                            "Existing Renumeration's Renumeration Tenders Total also remains Unchanged" );
        }
    }
}

=head2 test_split_me_with_charges

This tests the scenario where after a split has happened one of the Renumerations is left with a Negative Total
which means that it should actually be a charge, see CANDO-3094 for a detailed explanation of this scenario.

=cut

sub test_split_me_with_charges : Tests {
    my $self = shift;

    note "Cancelling Existing RMA";
    $self->_cancel_return( $self->{return} );

    # create an Address that will incur charges for an Exchange
    my $ship_address = Test::XTracker::Data->order_address( {
        address => 'create',
        country => Test::XTracker::Data->get_non_charge_free_state()->country,
    } );
    my $shipment   = $self->{shipment};
    $shipment->update( { shipment_address_id => $ship_address->id } );

    # get the Shipment Items and change their values ahead of using them in tests
    my @ship_items = @{ $self->{shipment_items} };

    # give some Renumeration Items Tax & Duty so that they get charged when Exchanged
    $ship_items[0]->update( { unit_price => 100, tax => 30, duty => 20 } );
    $ship_items[1]->update( { unit_price => 100, tax => 25, duty => 15 } );

    # change the value of the rest of the items so as to
    # use them in tests along with the above charged items
    $_->update( { unit_price => 50, tax => 0, duty => 0 } )     foreach ( @ship_items[2..4] );


    # create test scenarios, remember the Shipment Items are split in the following ways:
    #
    #   Exchange Items that will incur Tax & Duty Charges
    #   [0] - { unit_price => n/a, tax => 30, duty => 20 },
    #   [1] - { unit_price => n/a, tax => 25, duty => 15 },
    #
    #   Refund Items that will incur no charges
    #   [2] - { unit_price => 50, tax => 0, duty => 0 },
    #   [3] - { unit_price => 50, tax => 0, duty => 0 },
    #   [4] - { unit_price => 50, tax => 0, duty => 0 },

    my %tests = (
        "Sanity Check where Refund is greater than Exchange Charge, that splitting off a Refund Still Leaves a Refund behind" => {
            setup => {
                exchange_items => [ $ship_items[1] ],
                refund_items   => [ @ship_items[ 2..4 ] ],
                items_to_split => [ $ship_items[3] ],
            },
            expected => {
                number_of_renumerations_after => 2,
                original_renum_type => 'Card Refund',
                new_renum_type      => 'Card Refund',
                exchange_status_pre_split  => 'Return Hold',
                exchange_status_post_split => 'Return Hold',
            },
        },
        "Split off a Refund Item & Charged Items where the Charge is greater than the Refund on the new Renumeration" => {
            setup => {
                exchange_items => [ @ship_items[ 0,1 ] ],
                refund_items   => [ @ship_items[ 2..4 ] ],
                items_to_split => [ @ship_items[ 0..2 ] ],
            },
            expected => {
                number_of_renumerations_after => 2,
                original_renum_type => 'Card Refund',
                new_renum_type      => 'Card Debit',
                exchange_status_pre_split  => 'Return Hold',
                exchange_status_post_split => 'Exchange Hold',
            },
        },
        "Leave behind a Refund Item & Charged Items where the Charge is greater than the Refund on the original Renumeration" => {
            setup => {
                exchange_items => [ @ship_items[ 0,1 ] ],
                refund_items   => [ @ship_items[ 2..4 ] ],
                items_to_split => [ @ship_items[ 3,4 ] ],
            },
            expected => {
                number_of_renumerations_after => 2,
                original_renum_type => 'Card Debit',
                new_renum_type      => 'Card Refund',
                exchange_status_pre_split  => 'Return Hold',
                exchange_status_post_split => 'Exchange Hold',
            },
        },
        "Split off Refund Items leaving only Charged Items Behind on the Original" => {
            setup => {
                exchange_items => [ @ship_items[ 0,1 ] ],
                refund_items   => [ @ship_items[ 2..4 ] ],
                items_to_split => [ @ship_items[ 2..4 ] ],
            },
            expected => {
                number_of_renumerations_after => 2,
                original_renum_type => 'Card Debit',
                new_renum_type      => 'Card Refund',
                exchange_status_pre_split  => 'Return Hold',
                exchange_status_post_split => 'Exchange Hold',
            },
        },
        "Split off Charged Items leaving the Refund Items on the Original" => {
            setup => {
                exchange_items => [ @ship_items[ 0,1 ] ],
                refund_items   => [ @ship_items[ 2..4 ] ],
                items_to_split => [ @ship_items[ 0,1 ] ],
            },
            expected => {
                number_of_renumerations_after => 2,
                original_renum_type => 'Card Refund',
                new_renum_type      => 'Card Debit',
                exchange_status_pre_split  => 'Return Hold',
                exchange_status_post_split => 'Exchange Hold',
            },
        },
        "With a Shipping Refund & Charge, Split off Refund Items leaving the Charged Items on the Original" => {
            setup => {
                exchange_items => [ @ship_items[ 0,1 ] ],
                refund_items   => [ @ship_items[ 2..4 ] ],
                items_to_split => [ @ship_items[ 2..4 ] ],
                shipping => {
                    shipping    => 5,
                    misc_refund => -10,
                },
            },
            expected => {
                number_of_renumerations_after => 2,
                original_renum_type => 'Card Debit',
                new_renum_type      => 'Card Refund',
                exchange_status_pre_split  => 'Return Hold',
                exchange_status_post_split => 'Exchange Hold',
            },
        },
        "With a Shipping Refund & Charge, Split off Charged Items leaving the Refund Items on the Original" => {
            setup => {
                exchange_items => [ @ship_items[ 0,1 ] ],
                refund_items   => [ @ship_items[ 2..4 ] ],
                items_to_split => [ @ship_items[ 0,1 ] ],
                shipping => {
                    shipping    => 5,
                    misc_refund => -10,
                },
            },
            expected => {
                number_of_renumerations_after => 2,
                original_renum_type => 'Card Refund',
                new_renum_type      => 'Card Debit',
                exchange_status_pre_split  => 'Return Hold',
                exchange_status_post_split => 'Exchange Hold',
            },
        },

        #
        # The following tests are checking that for an Exchange where the Renumeration initially create
        # is a 'Card Debit', meaning the Charge outways the Refund that there is NO change done to the
        # orginal Renumeration and that a New Renumeration IS NOT created. This is because of a BUG in the
        # way Returns with Exchanges with this scenario (Charge > Refund) is created - CANDO-8132 - and so
        # can't at the moment be tested to make sure there are no negative Refunds created. If these tests
        # start passing then you have either fixed this BUG or broken something else, please check before
        # changing these tests.
        #
        "Starting with an Exchange Hold, then split off a Refund still leaving a Charge Behind" => {
            setup => {
                exchange_items => [ @ship_items[ 0,1 ] ],
                refund_items   => [ $ship_items[ 2 ] ],
                items_to_split => [ $ship_items[ 2 ] ],
                do_not_flip_signs           => 1,
                do_not_calculate_new_totals => 1,
            },
            expected => {
                number_of_renumerations_after => 1,
                original_renum_type => 'Card Debit',
                new_renum_type      => undef,
                exchange_status_pre_split  => 'Exchange Hold',
                exchange_status_post_split => 'Exchange Hold',
            },
        },
        "Starting with an Exchange Hold, then split off one of the Charges leaving a Refund Behind" => {
            setup => {
                exchange_items => [ @ship_items[ 0,1 ] ],
                refund_items   => [ $ship_items[ 2 ] ],
                items_to_split => [ $ship_items[ 1 ] ],
                do_not_flip_signs           => 1,
                do_not_calculate_new_totals => 1,
            },
            expected => {
                number_of_renumerations_after => 1,
                original_renum_type => 'Card Debit',
                new_renum_type      => undef,
                exchange_status_pre_split  => 'Exchange Hold',
                exchange_status_post_split => 'Exchange Hold',
            },
        },
        "Starting with an Exchange Hold, then split off 2 items to create a Refund and leave a Charge behind" => {
            setup => {
                exchange_items => [ @ship_items[ 0,1 ] ],
                refund_items   => [ $ship_items[ 2 ] ],
                items_to_split => [ @ship_items[ 0,2 ] ],
                do_not_flip_signs           => 1,
                do_not_calculate_new_totals => 1,
            },
            expected => {
                number_of_renumerations_after => 1,
                original_renum_type => 'Card Debit',
                new_renum_type      => undef,
                exchange_status_pre_split  => 'Exchange Hold',
                exchange_status_post_split => 'Exchange Hold',
            },
        },
    );

    my %renum_types = map {
        $_->id => $_->type,
    } $self->rs('Public::RenumerationType')->all;

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expected= $test->{expected};

        # create a Return with an Exchange
        $self->_create_return_with_exchange( $shipment, $setup->{exchange_items}, $setup->{refund_items} );
        my $return       = $self->{return};
        my $renumeration = $self->{renumeration};

        my $renumeration_rs   = $self->{renumeration_rs};      # this returns ALL renumerations for the Return
        my $new_renum_rs      = $self->{new_renum_rs};         # this returns only NEW renumerations for the Return
        my $exchange_shipment = $self->{exchange_shipment};    # get the Exchange Shipment created

        # just make sure the starting Status of the Exchange Shipment is ok
        is( $exchange_shipment->shipment_status->status, $expected->{exchange_status_pre_split},
                        "Exchange Shipment Status before Split is as Expected: '" . $expected->{exchange_status_pre_split} . "'" );

        # Renumeration Items are sorted by Shipment Item Id
        my @renum_items  = @{ $self->{renum_items} };

        # update Shipping Refund/Charges to ZERO and then override if the test wants to
        $renumeration->update( { shipping => 0, misc_refund => 0 } );
        $renumeration->update( $setup->{shipping} )     if ( $setup->{shipping} );

        # build up data for the Return Items used in the test
        my @shipment_item_id_list = map { $_->id } @{ $setup->{items_to_split} };
        my @renum_items_to_split  = $self->{renum_item_rs}->search( {
            shipment_item_id => { 'IN' => \@shipment_item_id_list },
        } )->all;
        my @return_items_to_split = $return->return_items
                                            ->search( { shipment_item_id => { IN => \@shipment_item_id_list } } )
                                                ->all;

        # for the sake of these tests Pass QC all the Return Items to be Split Off
        $self->_pass_qc_items( @return_items_to_split );

        # by emptying this Array, no New Totals will be calculated and therefore
        # it will be expected that the Renumeration will stay the same
        @renum_items_to_split = ()      if ( $setup->{do_not_calculate_new_totals} );

        # work out the Renumeration Totals
        my $original_renum_curr_total = $renumeration->grand_total;
        my $original_renum_new_total  = $original_renum_curr_total;
        my $new_renum_total     = sum( 0, map {
                  $_->unit_price
                + $_->tax
                + $_->duty
            } @renum_items_to_split
        ) + ( $renumeration->shipping + $renumeration->misc_refund );
        $original_renum_new_total = $original_renum_curr_total - $new_renum_total;

        # work out what the new & original renumeration item values are expected to be
        my %expected_new_renum_items = map {
            $_->shipment_item_id => {
                unit_price => _d3( $_->unit_price ),
                tax        => _d3( $_->tax ),
                duty       => _d3( $_->duty ),
            },
        } @renum_items_to_split;

        my %expected_orig_renum_items = map {
            $_->shipment_item_id => {
                unit_price => _d3( $_->unit_price ),
                tax        => _d3( $_->tax ),
                duty       => _d3( $_->duty ),
            },
        } grep { !exists( $expected_new_renum_items{ $_->shipment_item_id } ) }
            @renum_items;

        unless ( $setup->{do_not_flip_signs} ) {
            # if the expected Renumeration Type is 'Card Debit' meaning a charge
            # then the totals will need to be positive hence flipping their sign
            if ( $expected->{original_renum_type} eq 'Card Debit' ) {
                $original_renum_new_total *= -1;
                $self->_flip_item_value_signs( \%expected_orig_renum_items );
            }
            if ( ( $expected->{new_renum_type} // '') eq 'Card Debit' ) {
                $new_renum_total *= -1;
                $self->_flip_item_value_signs( \%expected_new_renum_items );
            }
        }

        # build a Return Item Result Set to be passed to the method
        my $return_item_rs  = $return->return_items->search( {
            shipment_item_id => { IN => \@shipment_item_id_list },
        } );

        # Call the method
        $renumeration->split_me( $return_item_rs );
        $renumeration->discard_changes;
        $exchange_shipment->discard_changes;

        cmp_ok( $renumeration_rs->reset->count, '==', $expected->{number_of_renumerations_after},
                    "Total number of Renumeration records now created as expected: " . $expected->{number_of_renumerations_after} );

        # get the new Renumeration record created after the split
        my ( $new_renum_rec ) = $new_renum_rs->reset->all;
        if ( !defined $expected->{new_renum_type} ) {
            ok( !defined $new_renum_rec, "Didn't get a NEW Renumeration Record" );
        }

        # check the Status of the Exchange Shipment after the split
        is( $exchange_shipment->shipment_status->status, $expected->{exchange_status_post_split},
                        "Exchange Shipment Status after Split is as Expected: '" . $expected->{exchange_status_post_split} . "'" );

        is( $renum_types{ $renumeration->renumeration_type_id }, $expected->{original_renum_type},
                                    "Original Renumeration Type as Expected: '" . $expected->{original_renum_type} . "'" );
        is( $renum_types{ $new_renum_rec->renumeration_type_id }, $expected->{new_renum_type},
                                    "New Renumeration Type as Expected: '" . $expected->{new_renum_type} . "'" )
                                if ( defined $expected->{new_renum_type} );

        cmp_ok( _d3( $renumeration->grand_total ), '==', _d3( $original_renum_new_total ),
                        "Original Renumeration Total is now: " . _d3( $original_renum_new_total ) );
        cmp_ok( _d3( $new_renum_rec->grand_total ), '==', _d3( $new_renum_total ),
                        "New Renumeration Total is as Expected: " . _d3( $new_renum_total ) )
                                if ( defined $expected->{new_renum_type} );

        $self->_check_renumeration_values( $renumeration, \%expected_orig_renum_items, "Original Renumeration" );
        $self->_check_renumeration_values( $new_renum_rec, \%expected_new_renum_items, "New Renumeration" )
                                if ( defined $expected->{new_renum_type} );

        # finally Cancel the Return to make sure
        # everything is stable for the next test
        note "Cancelling Return";
        # put all Split Off items back to Awaiting Return
        $self->_set_return_item_status( $RETURN_ITEM_STATUS__AWAITING_RETURN, @return_items_to_split );
        $self->_cancel_return( $return );
    }
}

=head2 test_split_if_needed

Test the 'split_if_needed' method found on the 'Public::Return' class which is used to split
off from one Return Renumeration record any 'Passed QC' and/or 'Failed QC Awaiting Decision'
return items onto a New Renumeration record, but only if they need to be.

=cut

sub test_split_if_needed : Tests() {
    my $self    = shift;

    my $return          = $self->{return};
    my $renumeration_rs = $self->{renumeration_rs};
    my $new_renum_rs    = $self->{new_renum_rs};
    my $return_item_rs  = $return->return_items;            # get a resultset for all return items
    my @items           = @{ $self->{return_items} };       # get the items which are sorted in a known order

    # Return Item Status mapping
    my %status_map  = (
        'Booked In' => $RETURN_ITEM_STATUS__BOOKED_IN,
        'Passed QC' => $RETURN_ITEM_STATUS__PASSED_QC,
        'Failed QC' => $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
        'Cancelled' => $RETURN_ITEM_STATUS__CANCELLED,
    );

    my %tests   = (
        "All Passed QC, No Split should happen" => {
            setup => {
                'Passed QC' => [ @items ],
            },
            expected => {
                number_of_renumerations_after => 1,
            },
        },
        "2 Passed QC, The rest Awaiting Return or Booked In, Passed QC items should be split off" => {
            setup => {
                'Passed QC' => [ @items[0,1] ],
                'Booked In' => [ @items[2,4] ],
            },
            expected => {
                passed_items    => [ @items[0,1] ],
                failed_items    => undef,
                number_of_renumerations_after => 2,
            },
        },
        "All Failed QC, No Split should happen" => {
            setup => {
                'Failed QC' => [ @items ],
            },
            expected => {
                number_of_renumerations_after => 1,
            },
        },
        "2 Passed QC, 2 Failed QC, 1 Awaiting Return, Passed QC split on one Invoice and Failed QC split on another" => {
            setup => {
                'Passed QC' => [ @items[0,2] ],
                'Failed QC' => [ @items[1,3] ],
            },
            expected => {
                passed_items    => [ @items[0,2] ],
                failed_items    => [ @items[1,3] ],
                number_of_renumerations_after => 3,
            },
        },
        "2 Passed QC, The rest Failed QC, Passed QC items should be split off" => {
            setup => {
                'Passed QC' => [ @items[0,2] ],
                'Failed QC' => [ @items[1,3,4] ],
            },
            expected => {
                passed_items    => [ @items[0,2] ],
                failed_items    => [ @items[1,3,4] ],
                number_of_renumerations_after => 2,
            },
        },
        "2 Failed QC, The rest Awaiting Return or Booked In, Failed QC items should be split off" => {
            setup => {
                'Failed QC' => [ @items[3,4] ],
                'Booked In' => [ @items[2,1] ],
            },
            expected => {
                passed_items    => undef,
                failed_items    => [ @items[3,4] ],
                number_of_renumerations_after => 2,
            },
        },
        "2 Failed QC, 2 Passed QC, 1 Cancelled, Passed QC items only should be split off" => {
            setup => {
                'Passed QC' => [ @items[0,2] ],
                'Failed QC' => [ @items[3,4] ],
                'Cancelled' => [ $items[1] ],
            },
            expected => {
                passed_items    => [ @items[0,2] ],
                failed_items    => undef,
                number_of_renumerations_after => 2,
            },
        },
        "2 Passed QC, The Rest Cancelled, No Split should happen" => {
            setup => {
                'Passed QC' => [ @items[3,4] ],
                'Cancelled' => [ @items[0..2] ],
            },
            expected => {
                number_of_renumerations_after => 1,
            },
        },
        "2 Failed QC, The Rest Cancelled, No Split should happen" => {
            setup => {
                'Failed QC' => [ @items[3,4] ],
                'Cancelled' => [ @items[0..2] ],
            },
            expected => {
                number_of_renumerations_after => 1,
            },
        },
        "1 Failed QC, 1 Passed QC, 1 Booked In, 1 Awaiting Return, 1 Cancelled, Passed QC items and Failed QC items should be split off" => {
            setup => {
                'Passed QC' => [ $items[0] ],
                'Failed QC' => [ $items[4] ],
                'Booked In' => [ $items[2] ],
                'Cancelled' => [ $items[1] ],
            },
            expected => {
                passed_items    => [ $items[0] ],
                failed_items    => [ $items[4] ],
                number_of_renumerations_after => 3,
            },
        },
        "1 Failed QC, 1 Passed QC, 1 Failed QC Accepted, 1 Failed QC Rejected, 1 Failed QC, ???" => {
            setup => {
                'Passed QC' => [ $items[0] ],
                'Failed QC' => [ $items[4] ],
                'Booked In' => [ $items[2] ],
                'Cancelled' => [ $items[1] ],
            },
            expected => {
                passed_items    => [ $items[0] ],
                failed_items    => [ $items[4] ],
                number_of_renumerations_after => 3,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $expected= $test->{expected};

        $self->_reset_data;

        # now setup the return items that have been asked for
        foreach my $status ( keys %{ $test->{setup} } ) {
            $self->_set_return_item_status( $status_map{ $status }, @{ $test->{setup}{ $status } } );
        }

        # Call the method
        $return->discard_changes->split_if_needed();
        cmp_ok( $renumeration_rs->reset->count, '==', $expected->{number_of_renumerations_after},
                    "Total number of Renumeration records now created as expected: " . $expected->{number_of_renumerations_after} );

        # if there is expected to be a renumeration for either Passed or Failed then check
        if ( $expected->{passed_items} || $expected->{failed_items} ) {
            my @new_renum_recs  = $new_renum_rs->reset->all;
            if ( @new_renum_recs ) {
                foreach my $renum ( @new_renum_recs ) {
                    # work out whether to check it against 'passed_items' or 'failed_items'
                    my $item_type   = $self->_get_item_type_of_renumeration( $renum );
                    # delete items as should only check each once
                    my $expect_items= delete $expected->{ "${item_type}_items" };
                    is_deeply(
                        [ sort { $a <=> $b } map { $_->shipment_item_id } $renum->renumeration_items->all ],
                        [ sort { $a <=> $b } map { $_->shipment_item_id } @{ $expect_items } ],
                        "Checking Renumeration: " . $renum->id . ", for '${item_type}' items and got all expected"
                    );
                }
            }
            else {
                fail("No New Renumerations have been created, but were expected");
            }
        }
        else {
            cmp_ok( $new_renum_rs->reset->count, '==', 0, "NO New Renumerations have been created" );
        }
    }
}

=head2 test_subsequent_splits

This tests the 'split_if_needed' method on the 'Public::Return' class that it works
correctly when a split has already happened and then a subsequent call is made to
it when another Return Item is QC'd after some have already been QC'd.

=cut

sub test_subsequent_splits : Tests() {
    my $self    = shift;

    my $return          = $self->{return};
    my $renumeration_rs = $self->{renumeration_rs};
    my $new_renum_rs    = $self->{new_renum_rs};
    my $return_item_rs  = $return->return_items;            # get a resultset for all return items
    my @items           = @{ $self->{return_items} };       # get the items which are sorted in a known order

    # Return Item Status mapping
    my %status_map  = %{ $self->{return_item_status_map} };

    my %tests   = (
        "Fail QC the last outstanding Return Item, with Items already set to 'Passed', 'Failed Accepted' or 'Failed Rejected'" => {
            split_first => {
                'Passed QC' => [ @items[0,1] ],
                'Failed QC' => [ @items[2,3] ],
                do_after_split => {
                    'Failed QC Accepted'=> [ $items[2] ],
                    'Failed QC Rejected'=> [ $items[3] ],
                },
            },
            setup => {
                'Failed QC' => [ $items[4] ],
            },
            expected => {
                number_of_renumerations_after => 3,
            },
        },
        "Pass QC the last outstanding Return Item, with Items already set to 'Passed', 'Failed Accepted' or 'Failed Rejected'" => {
            split_first => {
                'Passed QC' => [ @items[0,1] ],
                'Failed QC' => [ @items[2,3] ],
                do_after_split => {
                    'Failed QC Accepted'=> [ $items[2] ],
                    'Failed QC Rejected'=> [ $items[3] ],
                },
            },
            setup => {
                'Passed QC' => [ $items[4] ],
            },
            expected => {
                number_of_renumerations_after => 3,
            },
        },
        "Fail QC the last outstanding Return Item, with Items already set to 'Passed' & 'Failed'" => {
            split_first => {
                'Passed QC' => [ @items[0,1] ],
                'Failed QC' => [ @items[2,3] ],
            },
            setup => {
                'Failed QC' => [ $items[4] ],
            },
            expected => {
                number_of_renumerations_after => 3,
            },
        },
        "Pass QC the last outstanding Return Item, with Items already set to 'Passed' & 'Failed'" => {
            split_first => {
                'Passed QC' => [ @items[0,1] ],
                'Failed QC' => [ @items[2,3] ],
            },
            setup => {
                'Passed QC' => [ $items[4] ],
            },
            expected => {
                number_of_renumerations_after => 3,
            },
        },
        "Pass QC a Subsequent Return Item with some Items still Awaiting Return" => {
            split_first => {
                'Passed QC' => [ @items[0,1] ],
            },
            setup => {
                'Passed QC' => [ $items[2] ],
            },
            expected => {
                passed_items    => [ $items[2] ],
                number_of_renumerations_after => 3,
            },
        },
        "Fail QC a Subsequent Return Item with some Items still Awaiting Return" => {
            split_first => {
                'Failed QC' => [ @items[0,1] ],
            },
            setup => {
                'Failed QC' => [ $items[2] ],
            },
            expected => {
                failed_items    => [ $items[2] ],
                number_of_renumerations_after => 3,
            },
        },
        "Pass QC the Final Item after all Items previously have been Failed" => {
            split_first => {
                'Failed QC' => [ @items[0..3] ],
            },
            setup => {
                'Passed QC' => [ $items[4] ],
            },
            expected => {
                number_of_renumerations_after => 2,
            },
        },
        "Fail QC the Final Item after all Items previously have been Passed" => {
            split_first => {
                'Passed QC' => [ @items[0..3] ],
            },
            setup => {
                'Failed QC' => [ $items[4] ],
            },
            expected => {
                number_of_renumerations_after => 2,
            },
        },
        "Fail QC the Final Item after all Items previously have been Failed" => {
            split_first => {
                'Failed QC' => [ @items[0..3] ],
            },
            setup => {
                'Failed QC' => [ $items[4] ],
            },
            expected => {
                number_of_renumerations_after => 2,
            },
        },
        "Pass QC the Final Item after all Items previously have been Passed" => {
            split_first => {
                'Passed QC' => [ @items[0..3] ],
            },
            setup => {
                'Passed QC' => [ $items[4] ],
            },
            expected => {
                number_of_renumerations_after => 2,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $expected= $test->{expected};

        $self->_reset_data;

        # setup the data and run the 'split_if_needed' method to
        # simulate a prior call to the method before doing the test
        my @exclude_renum_rec_ids   = $self->_setup_and_split( $test->{split_first} );

        # now setup the return items that have been asked for
        foreach my $status ( keys %{ $test->{setup} } ) {
            $self->_set_return_item_status( $status_map{ $status }, @{ $test->{setup}{ $status } } );
        }

        # Call the method
        $return->discard_changes->split_if_needed();
        cmp_ok( $renumeration_rs->reset->count, '==', $expected->{number_of_renumerations_after},
                    "Total number of Renumeration records now created as expected: " . $expected->{number_of_renumerations_after} );

        # if there is expected to be a renumeration for either Passed or Failed then check
        if ( $expected->{passed_items} || $expected->{failed_items} ) {
            CHECK_ITEMS:
            foreach my $item_type ( qw( passed failed ) ) {
                my $expect_items    = $expected->{ "${item_type}_items" };
                next CHECK_ITEMS    if ( !$expect_items );

                my @renum_recs  = $self->_get_renumerations_for_items( $expect_items );
                cmp_ok( @renum_recs, '==', 1, "Only found One Renumeration for '${item_type}' items" );
                my $renum   = $renum_recs[0];

                # check that the only items for the Renumeration are the ones expected
                is_deeply(
                    [ sort { $a <=> $b } map { $_->shipment_item_id } $renum->renumeration_items->all ],
                    [ sort { $a <=> $b } map { $_->shipment_item_id } @{ $expect_items } ],
                    "Checking Renumeration: " . $renum->id . ", for '${item_type}' items and got all expected"
                );
            }
        }
        else {
            my $renum_count = $new_renum_rs->search( { id => { 'NOT IN' => \@exclude_renum_rec_ids } } )->count;
            cmp_ok( $renum_count, '==', 0, "NO New Renumerations have been created" );
        }
    }
}

#--------------------------------------------------------------------------------
sub _pass_qc_items {
    my ( $self, @items )    = @_;
    return $self->_set_return_item_status( $RETURN_ITEM_STATUS__PASSED_QC, @items );
}

sub _fail_qc_items {
    my ( $self, @items )    = @_;
    return $self->_set_return_item_status( $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION, @items );
}

sub _set_return_item_status {
    my ( $self, $status_id, @items )    = @_;

    my @ids;
    foreach my $item ( @items ) {
        $item->discard_changes->update( {
            return_item_status_id   => $status_id,
        } );
        push @ids, $item->id;
        if ( $status_id == $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED ) {
            # if an Item is QC Rejected then it
            # is removed from any Renumerations
            #$self->rs('Public::RenumerationItem')->search( {
            #    shipment_item_id => $item->shipment_item_id,
            #} )->delete;
        }
    }

    # if called in 'void' context
    return      if ( !defined wantarray );

    # return a ResultSet of just the Ids updated
    return $self->{return}->discard_changes
                            ->return_items
                                ->search( {
        'me.id' => { IN => \@ids },
    } );
}

# reset Return test data back to
# everything being Awaiting Return
# and with one Renumeration Record
sub _reset_data {
    my $self    = shift;

    $self->{return}->discard_changes->return_items->update( {
        return_item_status_id => $RETURN_ITEM_STATUS__AWAITING_RETURN,
    } );

    my $orig_renumeration   = $self->{renumeration};
    my @renum_recs_to_delete= $self->{new_renum_rs}->all;

    foreach my $renum ( @renum_recs_to_delete ) {
        $renum->discard_changes->renumeration_items->update( { renumeration_id => $orig_renumeration->id } );
        $renum->renumeration_tenders->delete;
        $renum->link_return_renumerations->delete;
    }
    $orig_renumeration->discard_changes;
    $orig_renumeration->update( {
        shipping    => 0,
        misc_refund => 0,
    } );

    $orig_renumeration->renumeration_tenders->update( {
        value => $orig_renumeration->grand_total,
    } );

    return;
}

# determine if a Renumeration record is for
# a list of Failed QC or Passed QC Return Items
sub _get_item_type_of_renumeration {
    my ( $self, $renum )    = @_;

    my %status_map  = (
        $RETURN_ITEM_STATUS__PASSED_QC                          => 'passed',
        $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION => 'failed',
    );

    # get any renumeration item
    my $renum_item  = $renum->renumeration_items->first;

    # now find the Return Item for the
    # Renumeration Item's Shipment Item Id
    my $item_type;
    ITEM:
    foreach my $item ( @{ $self->{return_items} } ) {
        if ( $item->discard_changes->shipment_item_id == $renum_item->shipment_item_id ) {
            $item_type  = $status_map{ $item->return_item_status_id };
            last ITEM;
        }
    }

    fail( "Couldn't find a valid Status for Renumeration: " . $renum->id )
                    if ( !$item_type );

    return $item_type;
}

# setup data and then run 'split_if_needed' method
sub _setup_and_split {
    my ( $self, $data ) = @_;

    my %status_map  = %{ $self->{return_item_status_map} };

    my $do_after_split  = delete $data->{do_after_split};

    foreach my $status ( keys %{ $data } ) {
        $self->_set_return_item_status( $status_map{ $status }, @{ $data->{ $status } } );
    }

    $self->{return}->discard_changes->split_if_needed;

    if ( $do_after_split ) {
        foreach my $status ( keys %{ $do_after_split } ) {
            $self->_set_return_item_status( $status_map{ $status }, @{ $do_after_split->{ $status } } );
        }
    }

    # get any new Renumeration Rec Ids created
    my @new_renum_rec_ids   = map { $_->id } $self->{new_renum_rs}->reset->all;

    return @new_renum_rec_ids;
}

# get a unique list of Renumerations
# for a list of Return Items
sub _get_renumerations_for_items {
    my ( $self, $items )    = @_;

    my @shipment_item_ids_to_search = map { $_->shipment_item_id } @{ $items };
    #$self->schema->storage->debug(1);
    my @renum_recs  = $self->{renumeration_rs}->reset->search(
        {
            shipment_item_id  => { IN => \@shipment_item_ids_to_search }
        },
        {
            join    => 'renumeration_items',
            distinct=> 1,
        }
    )->all;
    #$self->schema->storage->debug(0);

    return @renum_recs;
}

# just creates a 'renumeration' record
sub _create_renumeration {
    my $self    = shift;

    my $renumeration = $self->rs('Public::Renumeration')->create( {
        shipment_id             => $self->{shipment}->id,
        invoice_nr              => '',
        renumeration_type_id    => $RENUMERATION_TYPE__CARD_REFUND,
        renumeration_class_id   => $RENUMERATION_CLASS__RETURN,
        renumeration_status_id  => $RENUMERATION_STATUS__PENDING,
    } );

    $renumeration->create_related( 'link_return_renumerations', { return_id => $self->{return}->id } );

    return $renumeration->discard_changes;
}

# check out the values of a Renumeration record based on its Type
sub _check_renumeration_values {
    my ( $self, $renum_rec, $expected_item_values, $test_message ) = @_;

    note "${test_message}: Renumeration Type: '" . $renum_rec->renumeration_type->type . "'";

    my @items = $renum_rec->renumeration_items->all;

    if ( $renum_rec->renumeration_type_id == $RENUMERATION_TYPE__CARD_REFUND ) {
        cmp_ok( $renum_rec->shipping, '>=', 0, "${test_message}: 'shipping' is >= ZERO" );
        cmp_ok( $renum_rec->misc_refund, '<=', 0, "${test_message}: 'misc_refund' is <= ZERO" );
        cmp_ok( $renum_rec->renumeration_tenders->count(), '>', 0, "At least one Renumeration Tender Record found" );
        cmp_ok( _d3( $renum_rec->renumeration_tenders->get_column('value')->sum ), '==', _d3( $renum_rec->grand_total ),
                        "and Renumeration Tenders Total is as Expected: " . _d3( $renum_rec->grand_total ) );
    }
    elsif ( $renum_rec->renumeration_type_id == $RENUMERATION_TYPE__CARD_DEBIT ) {
        cmp_ok( $renum_rec->shipping, '<=', 0, "${test_message}: 'shipping' is <= ZERO" );
        cmp_ok( $renum_rec->misc_refund, '>=', 0, "${test_message}: 'misc_refund' is >= ZERO" );
        cmp_ok( $renum_rec->renumeration_tenders->count(), '==', 0, "No Renumeration Tenders for a Debit Renumeration" );
    }
    else {
        fail( "${test_message}: Unknown Renumeration Type to check: " . $renum_rec->renumeration_type_id );
        return;
    }

    # check the Item Values
    my %got_item_values = map {
        $_->shipment_item_id => {
            unit_price => _d3( $_->unit_price ),
            tax        => _d3( $_->tax ),
            duty       => _d3( $_->duty ),
        }
    } @items;

    cmp_deeply( \%got_item_values, $expected_item_values, "${test_message}: Item Values are as Expected" )
                            or diag "ERROR - Item Values are NOT as Expected:\n"
                                  . "Got: " . p( %got_item_values ) . "\n"
                                  . "Expected: " . p( $expected_item_values );

    return;
}

# Helper to Cancel a Return (RMA)
sub _cancel_return {
    my ( $self, $return ) = @_;

    $self->{domain}->cancel( {
        return_id     => $return->id,
        send_email    => 0,
        stock_manager => $self->{stock_manager},
        operator_id   => $APPLICATION_OPERATOR_ID,
    } );

    return;
}

# creates Return with some Items being Exchanges
# populates $self->{exchange_shipment} with the
# resulting Exchange Shipment
sub _create_return_with_exchange {
    my ( $self, $shipment, $exchange_items, $refund_items ) = @_;

    # specify the Exchange Items
    my %items_to_return = map {
        $_->id => {
            type             => 'Exchange',
            reason_id        => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
            exchange_variant => $_->variant_id,     # Exchange it with itself
        },
    } @{ $exchange_items };

    # now add in the Refund Items
    %items_to_return = (
        %items_to_return,
        map {
            $_->id => { type => 'Return', reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL }
        } @{ $refund_items },
    );

    $self->_create_return( $shipment, \%items_to_return );
    $self->{exchange_shipment} = $self->{return}->exchange_shipment;

    return;
}

# creates a Return for a Shipment and a given list of Items passed in as a
# Hash Ref and populates '$self' with the resulting records that are created
sub _create_return {
    my ( $self, $shipment, $items ) = @_;

    my $return  = $self->{domain}->create( {
        operator_id     => $APPLICATION_OPERATOR_ID,
        shipment_id     => $shipment->id,
        pickup          => 0,
        refund_type_id  => $RENUMERATION_TYPE__CARD_REFUND,
        return_items    => $items,
    } );
    note "Return Created - RMA: " . $return->rma_number;

    $self->{return}         = $return->discard_changes;
    $self->{return_items}   = [ $return->return_items->search( {}, { order_by => 'shipment_item_id' } )->all ];
    $self->{renumeration_rs}= $return->renumerations->search( {}, { order_by => 'id DESC' } );
    $self->{renumeration}   = $return->renumerations->first;
    $self->{renum_items}    = [ $self->{renumeration}->renumeration_items->search( {}, { order_by => 'shipment_item_id' } )->all ];
    $self->{renum_item_rs}  = $self->{renumeration}->renumeration_items->search( {}, { order_by => 'shipment_item_id' } );
    $self->{new_renum_rs}   = $self->{renumeration_rs}->search( { id => { '!=' => $self->{renumeration}->id } } );

    return;
}

# helper to flip the signs of the unit_price,
# tax & duty of expected items in tests
sub _flip_item_value_signs {
    my ( $self, $items ) = @_;

    foreach my $item_id ( keys %{ $items } ) {
        my $item = $items->{ $item_id };
        foreach my $type ( qw( unit_price tax duty ) ) {
            $item->{ $type } *= -1      if ( $item->{ $type } != 0 );
            $item->{ $type }  = _d3( $item->{ $type } );
        }
    }

    return;
}

# explicitly set a value to have 3 decimal places,
# this is for numeric comparison tests that sometimes
# go a bit awry when numbers for the DB are compared
# against numbers from a calculation
sub _d3 {
    my $value   = shift;
    return sprintf( '%0.3f', $value );
}

Test::Class->runtests;
