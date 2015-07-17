#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 NAME

cancel_pre_order.t - Cancel a Pre-Order or Pre-Order Items

=head1 DESCRIPTION

This tests that an Operator can Cancel a whole Pre-Order or just Selected Items.
From the Pre-Order summary page which you get to from the 'Stock Control->Reservation'
Main Nav option and then by either searching for a Pre-Order or for a Customer and
clicking on one of their Pre-Orders.

This test goes straight to the Pre-Order summary page and then tests:
    * Check Cancel Checkboxes are visible for Items that can be Cancelled
    * Cancelling Items results in a Pre-Order Refund being generated
    * Cancelling the Pre-Order as a Whole
    * Cancelling an Item after one Item has been Exported
    * Checks the Send Email page has the correct details

#TAGS inventory preorder cancelpreorder preorderview cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Mock::PSP;
use Test::XT::Flow;

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :branding
                                            :correspondence_templates
                                            :pre_order_status
                                            :pre_order_item_status
                                            :pre_order_refund_status
                                        );
use XTracker::Database::Reservation     qw( :email );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Reservations',
        'Test::XT::Data::Channel',      # required for PreOrder
        'Test::XT::Data::Customer',     # required for PreOrder
        'Test::XT::Data::PreOrder',
    ],
);

#---------- run tests ----------
_test_cancel_pre_order_page( $framework, 1 );
#-------------------------------

done_testing();


=head1 METHODS

=head2 _test_cancel_pre_order_page

    _test_cancel_pre_order_page( $framework, $ok_to_do_flag );

This will just go through a Client Test to make sure Items can
be Selected or the Whole Pre-Order can be Cancelled.

=cut

sub _test_cancel_pre_order_page {
    my ( $framework, $oktodo )  = @_;

    SKIP: {
        skip "_test_cancel_pre_order_page", 1   if ( !$oktodo );

        note "TESTING 'Order Cancel' page";

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
        my $pre_order   = $framework->pre_order;
        my $pre_order_id= $pre_order->id;
        my @pre_order_items = $pre_order->pre_order_items
                                            ->search( undef, { order_by => 'id' } )
                                                ->all;
        my $cancel_email_log_rs = $pre_order->pre_order_email_logs
                                                ->search(
                                                        {
                                                            correspondence_templates_id => $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__CANCEL,
                                                            operator_id                 => $itgod_op->id,
                                                        },
                                                        {
                                                            order_by => 'id DESC',
                                                        }
                                                    );

        my $max_item_id = $#pre_order_items;
        my $mech        = $framework->mech;

        # set the Customer's Language to be 'French' which should
        # mean the Email From address should be localised
        $pre_order->customer->set_language_preference('fr');

        $framework->mech__reservation__pre_order_summary( $pre_order_id );
        _check_items_have_cancel_checkboxes( $mech, \@pre_order_items, 0 );
        _check_refunds_shown_on_page( $mech, $pre_order );

        note "Cancel 2 Items";
        $mech->log_snitch->pause;        # pause because of known error with connecting to the PSP
        $framework->mech__reservation__pre_order_summary_cancel_items( [
                                                                    $pre_order_items[0]->id,
                                                                    $pre_order_items[1]->id,
                                                                ] );
        $mech->log_snitch->unpause;
        _discard_changes( $pre_order, @pre_order_items );
        like( $mech->app_status_message, qr/Pre-Order Items have been Cancelled/i, "Found 'Cancelled' Success Message" );
        like( $mech->app_info_message, qr/A Refund was generated but couldn't be processed/i,
                            "Because PSP can't be Mocked: Found 'Couldn't Process Refund' Info Message" );
        cmp_ok( $pre_order->is_cancelled, '==', 0, "Pre-Order it'self is NOT Cancelled" );
        cmp_ok( $pre_order->pre_order_refunds->count(), '==', 1, "Pre-Order has 1 'pre_order_refund' record associated with it" );
        _check_items_ok( [ @pre_order_items[0,1] ], [ @pre_order_items[2..$max_item_id] ] );
        _check_email_form( $mech, $pre_order, $itgod_op, { cancel_all => 0, cancel_items => [ $pre_order_items[0]->id, $pre_order_items[1]->id ] } );

        note "Check Sending an Email with NO Content DOESN'T get Sent";
        $mech->errors_are_fatal(0);
        $framework->mech__reservation__pre_order_summary_send_cancel_email( { email_content => "" } );
        $mech->errors_are_fatal(1);
        like( $mech->app_error_message, qr/Can't send Email: Missing or empty 'Email Text'/i, "Found 'without Text' warning message" );
        _check_email_form( $mech, $pre_order, $itgod_op, { cancel_all => 0, cancel_items => [ $pre_order_items[0]->id, $pre_order_items[1]->id ] } );
        cmp_ok( $cancel_email_log_rs->reset->count, '==', 0, "No Cancel Emails Logged" );

        note "Check the Email can be Sent when done properly";
        $framework->mech__reservation__pre_order_summary_send_cancel_email();
        _discard_changes( $pre_order, @pre_order_items );
        like( $mech->app_status_message, qr/Email has been Sent/i, "Found 'Email Sent' Status Message" );
        cmp_ok( $cancel_email_log_rs->reset->count, '==', 1, "One Cancel Email Logged" );

        note "Check All Cancelled items are shown correctly on the Summary page";
        _check_items_have_cancel_checkboxes( $mech, \@pre_order_items, 2 );
        _check_refunds_shown_on_page( $mech, $pre_order );

        note "Cancel the Pre-Order as a Whole";
        $mech->log_snitch->pause;
        $framework->mech__reservation__pre_order_summary_cancel_pre_order();
        $mech->log_snitch->unpause;
        _discard_changes( $pre_order, @pre_order_items );
        like( $mech->app_status_message, qr/Pre-Order has been Cancelled/i, "Found 'Cancelled' Success Message" );
        like( $mech->app_info_message, qr/A Refund was generated but couldn't be processed/i,
                            "Because PSP can't be Mocked: Found 'Couldn't Process Refund' Info Message" );
        cmp_ok( $pre_order->is_cancelled, '==', 1, "Pre-Order it'self IS Cancelled" );
        cmp_ok( $pre_order->pre_order_refunds->count(), '==', 2, "Pre-Order has 2 'pre_order_refund' records associated with it" );
        _check_items_ok( [ @pre_order_items ] );
        _check_email_form( $mech, $pre_order, $itgod_op, { cancel_all => 1, cancel_items => [ map { $_->id } @pre_order_items[2,3,4] ] } );

        $framework->mech__reservation__pre_order_summary_send_cancel_email();
        _discard_changes( $pre_order, @pre_order_items );
        like( $mech->app_status_message, qr/Email has been Sent/i, "Found 'Email Sent' Status Message" );
        cmp_ok( $cancel_email_log_rs->reset->count, '==', 2, "Two Cancel Emails Logged" );

        note "Check Cancelled items are shown correctly on the Summary page";
        _check_items_have_cancel_checkboxes( $mech, \@pre_order_items, scalar( @pre_order_items ) );
        _check_refunds_shown_on_page( $mech, $pre_order );

        note "Check Cancelling a Pre-Order where 1 Item has already been Exported";
        # reset the Pre-Order's state
        _reset_pre_order( $pre_order );
        # set 1 Item to be Exported which should be
        # excluded from being Cancelled
        $pre_order_items[2]->discard_changes->update_status( $PRE_ORDER_ITEM_STATUS__EXPORTED );

        $framework->mech__reservation__pre_order_summary( $pre_order_id );
        # make sure check boxes are only shown for Cancellable items
        _check_items_have_cancel_checkboxes( $mech, \@pre_order_items, 1 );

        $mech->log_snitch->pause;
        $framework->mech__reservation__pre_order_summary_cancel_pre_order();
        $mech->log_snitch->unpause;
        _discard_changes( $pre_order, @pre_order_items );
        like( $mech->app_status_message, qr/Pre-Order has been Cancelled/i, "Found 'Cancelled' Success Message" );
        like( $mech->app_info_message, qr/A Refund was generated but couldn't be processed/i,
                            "Because PSP can't be Mocked: Found 'Couldn't Process Refund' Info Message" );
        cmp_ok( $pre_order->is_cancelled, '==', 0, "Pre-Order it'self is NOT Cancelled" );
        cmp_ok( $pre_order->pre_order_refunds->count(), '==', 1, "Pre-Order has 1 'pre_order_refund' record associated with it" );
        _check_items_ok( [ @pre_order_items[0,1,3,4] ], [ $pre_order_items[2] ] );
        _check_email_form( $mech, $pre_order, $itgod_op, { cancel_all => 1 } );

        note "Skip Sending an Email";
        $framework->mech__reservation__pre_order_summary_skip_cancel_email();
        like( $mech->app_info_message, qr/Did Not Send an Email/i, "Found: 'Did Not Send an Email' message" );
        _discard_changes( $pre_order, @pre_order_items );
        cmp_ok( $cancel_email_log_rs->reset->count, '==', 0, "NO Cancel Email Logged" );

        note "Check Cancelled items are shown correctly on the Summary page";
        _check_items_have_cancel_checkboxes( $mech, \@pre_order_items, scalar( @pre_order_items ) );
        _check_refunds_shown_on_page( $mech, $pre_order );
    };

    return $framework;
}

#-----------------------------------------------------------------

=head2 _check_email_form

    _check_email_form( $mech_object, $dbic_pre_order, $dbic_operator, $args );

Test Helper to check the Send Email page that
sends the Pre-Order Cancellation Email.

=cut

sub _check_email_form {
    my ( $mech, $pre_order, $operator, $args )  = @_;

    my $form_data   = $mech->as_data()->{email_form};

    my $channel = $pre_order->customer->channel;
    my $from    = get_from_email_address( {
                                    channel_config  => $channel->business->config_section,
                                    department_id   => $operator->department_id,
                                    schema          => $channel->result_source->schema,
                                    locale          => $pre_order->customer->locale,
                                } );

    # get rid of stuff don't want to compare
    my $hidden  = delete $form_data->{hidden_fields};

    my $expected    = {
            'Send Email'    => 1,
            To              => $pre_order->customer->email,
            From            => $from,
            'Reply-To'      => $from,
            Subject         => re( qr/\w+.{5,}/ ),
            'Email Text'    => re( qr/\w+.{25,}/ ),
        };
    cmp_deeply( $form_data, $expected, "Email To, From, Reply-To, Subject, Body as expected" );
    like( $hidden->{email_content_type}, qr/\w{3,}/, "Hidden Field: 'email_content_type' has a value: '" . $hidden->{email_content_type} . "'" );
    cmp_ok( $hidden->{pre_order_id}, '==', $pre_order->id, "Hidden Field: 'pre_order_id' as expected: " . $pre_order->id );
    is( $hidden->{on_fail_url}, "/SendCancelEmail", "Hidden Field: 'on_fail_url' as expected: /SendCancelEmail" );
    like( $hidden->{redirect_url}, qr{/StockControl/Reservation/PreOrder/Summary},
                                        "Hidden Field: 'redirect_url' as expected: /StockControl/Reservation/PreOrder/Summary" );
    cmp_ok( $hidden->{template_id}, '==', $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__CANCEL,
                                            "Hidden Field: 'template_id' as expected: " . $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__CANCEL );

    # get the most recent Refund
    my $refund  = $pre_order->pre_order_refunds
                                ->search( undef, { order_by => 'id DESC' } )
                                    ->first;
    # make up the passback params to expect
    my %expect_passback = (
                passback_refund_id      => ( $refund ? $refund->id : '' ),
                passback_cancel_all     => ( $args->{cancel_all} ? 1 : '' ),
                passback_cancel_items   => ( $args->{cancel_items} ? join( ",", @{ $args->{cancel_items} } ) : '' ),
            );
    my %got_passback    = map { ( $_, $hidden->{ $_ } ) }
                                grep { m/^passback_/ } keys %{ $hidden };
    is_deeply( \%got_passback, \%expect_passback, "Hidden Fields: 'passback_*' fields as expected" );

    return;
}

=head2 _check_refunds_shown_on_page

    _check_refunds_shown_on_page( $mech_object, $dbic_pre_order );

Test Helper that checks that the refunds
have appeared on the Pre-Order Summary page.

=cut

sub _check_refunds_shown_on_page {
    my ( $mech, $pre_order )    = @_;

    my $refund_list     = $mech->as_data()->{refund_list};

    if ( !$pre_order->pre_order_refunds->count() ) {
        ok( !defined $refund_list, "When NO Refunds, 'Refunds' are not shown on page" );
        return;
    }

    my $expected_list   = $pre_order->pre_order_refunds->list_for_summary_page;

    ok( defined $refund_list, "Found 'Refunds' on page" );
    foreach my $idx ( 0..$#{ $expected_list } ) {
        my $on_page     = $refund_list->[ $idx ];
        my $expected    = $expected_list->[ $idx ];

        my $prefix  = "Refund Id: " . $expected->{refund_id};
        is( $on_page->{Status}, $expected->{status}, "${prefix}, on page Status as expected: " . $expected->{status} );
        is( $on_page->{'Total Value'}, $expected->{total_value}, "${prefix}, on page Total Value as expected: " . $expected->{total_value} );
    }

    return;
}

=head2 _check_items_have_cancel_checkboxes

    _check_items_have_cancel_checkboxes(
        $mech_object,
        $dbic_pre_order_items_array_ref,
        $expected_number_of_items_that_cant_be_cancelled,
    );

Test Helper that checks that only Items that can be
Cancelled have the check-box next to them to do it.

=cut

sub _check_items_have_cancel_checkboxes {
    my ( $mech, $pre_order_items, $expect_cant_cancel ) = @_;

    my $page_data   = $mech->as_data();
    my $item_list   = $page_data->{pre_order_item_list};

    my $cant_cancel_count   = 0;
    foreach my $item ( @{ $item_list } ) {
        my $cancel_item_col = $item->{CancelItem};
        if ( ref( $cancel_item_col ) eq 'HASH' ) {
            # get the Item Id from the data
            my $item_id = $cancel_item_col->{input_name};
            $item_id    =~ s/[^\d]//g;
            my ( $item )= grep { $_->id == $item_id } @{ $pre_order_items };

            if ( $item->discard_changes->can_be_cancelled ) {
                pass( "Pre-Order Item: ${item_id}, Can be Selected for Cancellation" );
            }
            else {
                fail( "Pre-Order Item: ${item_id}, Shouldn't be Selectable for Cancellation" );
            }
        }
        else {
            # keep a count of what can't be
            # cancelled for a future test
            $cant_cancel_count++;
        }
    }
    cmp_ok( $cant_cancel_count, '==', $expect_cant_cancel, "Found ${expect_cant_cancel} Item(s) that Can't be Cancelled" );

    # if there is still something to Cancel then the Cancel Buttons should be shown
    if ( $cant_cancel_count != scalar( @{ $pre_order_items } ) ) {
        ok( exists( $page_data->{cancel_pre_order_button} ), "Cancel Pre-Order Button SHOWN on Page" );
        ok( exists( $page_data->{cancel_pre_order_item_button} ), "Cancel Pre-Order Item Button SHOWN on Page" );
    }
    else {
        ok( !exists( $page_data->{cancel_pre_order_button} ), "Cancel Pre-Order Button NOT shown on Page" );
        ok( !exists( $page_data->{cancel_pre_order_item_button} ), "Cancel Pre-Order Item Button NOT shown on Page" );
    }

    return;
}


=head2 _check_items_ok

    _check_items_ok(
        $dbic_cancelled_items_array_ref,
        $dbic_not_cancelled_items_array_ref,
    );

Test Helper that checks Pre-Order Items have been Cancelled correctly.

=cut

sub _check_items_ok {
    my ( $cancelled, $not_cancelled )   = @_;

    foreach my $item ( @{ $cancelled } ) {
        my $prefix  = "Pre-Order Item: " . $item->id;
        cmp_ok( $item->is_cancelled, '==', 1, "$prefix, IS Cancelled" );
        cmp_ok( $item->pre_order_refund_items->count(), '==', 1, "$prefix, has a 'pre_order_refund_item' associated with it" );
    }

    foreach my $item ( @{ $not_cancelled } ) {
        my $prefix  = "Pre-Order Item: " . $item->id;
        cmp_ok( $item->is_cancelled, '==', 0, "$prefix, is NOT Cancelled" );
        cmp_ok( $item->pre_order_refund_items->count(), '==', 0, "$prefix, has NO 'pre_order_refund_item' associated with it" );
    }

    return;
}

=head2 _reset_pre_order

    _reset_pre_order( $dbic_pre_order );

Helper to reset the Pre-Order's state.

=cut

sub _reset_pre_order {
    my $pre_order   = shift;

    my @pre_order_items = $pre_order->pre_order_items->all;

    foreach my $item ( @pre_order_items ) {
        $item->pre_order_refund_items->delete;
        $item->pre_order_item_status_logs->delete;
        $item->update_status( $PRE_ORDER_ITEM_STATUS__COMPLETE );
    }

    foreach my $refund ( $pre_order->pre_order_refunds->all ) {
        $refund->pre_order_refund_status_logs->delete;
        $refund->pre_order_refund_failed_logs->delete;
        $refund->delete;
    }

    $pre_order->pre_order_status_logs->delete;
    $pre_order->pre_order_email_logs->delete;
    $pre_order->update_status( $PRE_ORDER_STATUS__COMPLETE );

    return;
}

=head2 _discard_changes

    _discard_changes( @dic_records );

Helper to discard changes for an array of dbic records.

=cut

sub _discard_changes {
    my @recs    = @_;

    foreach my $rec ( @recs ) {
        $rec->discard_changes;
    }

    return;
}

