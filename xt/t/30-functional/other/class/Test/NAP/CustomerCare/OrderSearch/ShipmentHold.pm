package Test::NAP::CustomerCare::OrderSearch::ShipmentHold;

use NAP::policy 'tt', 'test';
use parent 'NAP::Test::Class';

=head1 Test::NAP::CustomerCare::OrderSearch::ShipmentHold

Tests the 'Hold Shipment' option on the Left Hand Menu on the Order View page.

=cut

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :department
    :shipment_hold_reason
    :order_status
    :shipment_status
);


sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    $self->{framework}  = Test::XT::Flow->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
            'Test::XT::Flow::CustomerCare',
        ],
    } );

    $self->framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Customer Care/Customer Search',
                'Customer Care/Order Search',
            ],
        },
        dept => 'Customer Care',
    } );
    $self->{operator}   = $self->rs('Public::Operator')->find( { username => 'it.god' } );

    # get a Hold Reason, 'Other' & 'Incomplete Pick' are reasons
    # that are sometimes used specifically in the code and so are
    # not wanted for the tests, 'Prepaid Order' is also a special case
    $self->{hold_reason_rs} = $self->rs('Public::ShipmentHoldReason')
                                    ->search( { reason => { 'NOT IN' => [
        'Other',
        'Incomplete Pick',
        'Prepaid Order'
    ] } } );
}

sub shutdown : Test( shutdown ) {
    my $self    = shift;

    $self->SUPER::shutdown;
}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;

    my $order_details   = $self->framework->new_order(
        products    => 1,
        channel     => Test::XTracker::Data->any_channel,
    );
    $self->{order}      = $order_details->{order_object};
    $self->{shipment}   = $order_details->{shipment_object};
}

sub teardown : Test( teardown ) {
    my $self    = shift;

    $self->SUPER::teardown;
}


=head1 TESTS

=head2 test_can_not_release_some_shipment_hold_reasons

Tests that for some Shipment Hold Reasons which have their 'manually_releasable' flag
set to FALSE can't be Released using the 'Release Shipment' left hand menu options on
the 'Hold Shipment' page.

=cut

sub test_can_not_release_some_shipment_hold_reasons : Tests {
    my $self    = shift;

    my $order   = $self->{order};
    my $shipment= $self->{shipment};

    my $hold_reason = $self->{hold_reason_rs}->reset->first;
    my $original_releasable_flag = $hold_reason->manually_releasable;

    # update the 'manually_releasable' flag to be FALSE
    $hold_reason->update( { manually_releasable => 0 } );

    $shipment->set_status_hold(
        $self->{operator}->id,
        $hold_reason->id,
        'comment',
    );

    $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__hold_shipment;

    my $release_link = $self->find_link_by_text_on_page('Release Shipment');
    ok( !defined $release_link, "'Release Shipment' Left Hand option NOT Found" );

    my $pg_data = $self->pg_data->{hold_details};
    ok( !exists( $pg_data->{Reason}{select_name} ), "As Reason is not Manually Releasable there is NO Drop-Down" );
    is( $pg_data->{Reason}{value}, $hold_reason->reason, "Reason shown is as expected" );

    $self->framework->flow_mech__customercare__hold_shipment_submit( { comment => 'Updated Comment' } );
    $self->framework->flow_mech__customercare__hold_shipment;
    $pg_data = $self->pg_data->{hold_details};
    is( $pg_data->{Comments}, 'Updated Comment', "Can update the Comments" );
    is( $pg_data->{Reason}{value}, $hold_reason->reason, "and Reason has stayed the same" );

    note "allow the 'Release Shipment' option to be shown";
    note "by making the Reason 'Manually Releasable'";
    $hold_reason->discard_changes->update( { manually_releasable => 1 } );
    $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__hold_shipment;

    $pg_data = $self->pg_data->{hold_details};
    ok( ref( $pg_data->{Reason} ), "Now Reason is Manually Releasable Reason there is a Drop-Down" );
    is( $pg_data->{Reason}{select_selected}[1], $hold_reason->reason, "and the Reason is 'selected' in the Drop-Down" );

    note "now set 'manually_releasable' back to FALSE and check";
    note "that the 'Release Shipment' handler throws an error";
    $hold_reason->discard_changes->update( { manually_releasable => 0 } );
    $self->framework->catch_error(
        qr/Hold .* Can NOT be Manually Released/i,
        "Check 'Release Shipment' handler prevents releasing a NON Manually Releasable Hold Reason",
        'flow_mech__customercare__hold_release_shipment',
    );
    ok( $shipment->discard_changes->is_held, "Shipment is Still on Hold" );
    cmp_ok(
        $shipment->shipment_holds->count(),
        '==',
        1,
        "Shipment is still has Shipment Hold records"
    );

    note "Making the Hold Reason Manually Releasable";
    $hold_reason->discard_changes->update( { manually_releasable => 1 } );
    $self->framework->flow_mech__customercare__hold_shipment
                        ->flow_mech__customercare__hold_release_shipment;
    ok( $shipment->discard_changes->is_processing, "Shipment is NO Longer on Hold" );
    cmp_ok(
        $shipment->shipment_holds->count(),
        '==',
        0,
        "Shipment has NO Shipment Hold records"
    );


    # update the 'manually_releasable' flag to its original value
    $hold_reason->discard_changes->update( {
        manually_releasable => $original_releasable_flag,
    } );
}

=head2 test_hold_reason_information

Tests that the Shipment Hold page displays information about a Hold Reason
if there is information available.

=cut

sub test_hold_reason_information : Tests {
    my $self    = shift;

    my $order   = $self->{order};
    my $shipment= $self->{shipment};

    my $hold_reason = $self->{hold_reason_rs}->reset->first;
    my $original_information = $hold_reason->information;

    $shipment->set_status_hold(
        $self->{operator}->id,
        $hold_reason->id,
        'comment',
    );

    note "WITH Information for a Hold Reason";
    $hold_reason->update( { information => "Information on the Hold Reason" } );
    $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__hold_shipment;
    my $pg_data = $self->pg_data->{hold_details};
    ok( exists( $pg_data->{Information} ), "Found Information Label" );
    is( $pg_data->{Information}, "Information on the Hold Reason",
                    "and Information shown is as expected" );

    note "with NO Information for a Hold Reason";
    $hold_reason->discard_changes->update( { information => undef } );
    $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__hold_shipment;
    $pg_data = $self->pg_data->{hold_details};
    ok( !exists( $pg_data->{Information} ), "NO Information Label" );


    # update the 'information' field to its original value
    $hold_reason->discard_changes->update( {
        information => $original_information,
    } );
}

=head2 test_show_shipment_hold_log

This tests that Log of Shipment Hold Reasons which is in the 'shipment_hold_log'
table is shown on the 'Order Log' page which you get to from the 'View Status Log'
left hand menu option on the Order View page.

=cut

sub test_show_shipment_hold_log : Tests {
    my $self    = shift;

    my $order   = $self->{order};
    my $shipment= $self->{shipment};

    # make sure the Shipment has NO Logs and then
    # check that the Order Status Log page is ok
    # when there are no Logs to display
    note "check 'View Status Log' page when there are NO Shipment Hold Logs";
    $shipment->shipment_hold_logs->delete;
    $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__view_status_log;
    my $hold_logs = $self->pg_data->{page_data}{ $shipment->id }{shipment_hold_log};
    cmp_ok( @{ $hold_logs }, '==', 0, "There are No Shipment Hold Logs displayed" );


    # get a list of Hold Reasons
    my @hold_reasons = $self->{hold_reason_rs}->reset
                                ->search( {
        manually_releasable => 1,
    } )->all;

    # build up some Log entries by putting the Shipment on Hold
    # editing the Comment and Releasing and Putting back on Hold
    my @setup_logs = (
        {
            reason  => $hold_reasons[0],
            comment => 'comment',
        },
        {
            comment => 'updated comment',
        },
        {
            release_hold => 1,
            reason       => $hold_reasons[1],
            comment      => 'new comment',
        },
        {
            reason  => $hold_reasons[2],
        },
        {
            comment => 'updated new comment',
        },
    );
    my @expect_logs;

    # store the current reason & comment to help build up the expected logs
    my $current_reason;
    my $current_comment;

    note "put the Shipment on Hold a few times to populate the Logs";
    foreach my $setup ( @setup_logs ) {
        my $release_hold = delete $setup->{release_hold};

        $self->framework->flow_mech__customercare__release_shipment_hold__wrapper( $order->id )
                    if ( $release_hold );

        my $hold_args;
        if ( $setup->{reason} ) {
            $hold_args->{reason} = $setup->{reason}->id;
            $current_reason      = $setup->{reason};
        }
        if ( $setup->{comment} ) {
            $hold_args->{comment} = $setup->{comment};
            $current_comment      = $setup->{comment};
        }

        $self->framework->flow_mech__customercare__put_shipment_on_hold__wrapper( $order->id, $hold_args );

        push @expect_logs, {
            'Date'      => ignore(),
            'Operator'  => $self->{operator}->name,
            'Department'=> $self->{operator}->department->department,
            'Reason'    => $current_reason->reason,
            'Comment'   => $current_comment,
        },
    }

    # go to the 'View Status Log' page
    note "check the 'View Status Log' page to see the Logs";
    $self->framework->flow_mech__customercare__view_status_log;
    $hold_logs = $self->pg_data->{page_data}{ $shipment->id }{shipment_hold_log};
    cmp_deeply( $hold_logs, \@expect_logs, "Shipment Hold Logs as Expected" );
}

=head2 test_is_third_party_payment_release_button_present

This tests that the button to check the status of the third party payment system (PayPal) is present
if the order is on shipment hold and if it is on hold for the reason - Credit Hold - subject to external
payment review and if you have the right access to view the Shipment Hold page

=cut

sub test_is_third_party_payment_release_button_present : Tests {

    my $self    = shift;

    my $order   = $self->{order};
    my $shipment= $self->{shipment};

    my @tests = (
        {
            reason => $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS,
            button => 0,
        },
        {
            button => 0,
        },
        {
            reason => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
            button => 1,
        },
    );

    foreach my $test (@tests){
        if($test->{reason}//0){
            my $hold_reason = $self->{hold_reason_rs}->reset->search({
                id => $test->{reason}})->first;
            $shipment->set_status_processing($self->{operator}->id);
            $shipment->shipment_holds->delete;

            $shipment->set_status_hold(
            $self->{operator}->id,
            $hold_reason->id,
            'comment',
            );
        }
        else {
            $shipment->set_status_processing($self->{operator}->id);
            $shipment->shipment_holds->delete;
        }

        $shipment->discard_changes;

        $self->framework->flow_mech__customercare__orderview( $order->id )
                            ->flow_mech__customercare__hold_shipment;
        my $pg_data = $self->pg_data()->{hold_details}{Unknown} // [];
        my $button_is_present = scalar(grep {$_->{value}=~/button.*refresh.*payment/i} @{ $pg_data } );
        if($test->{button}) {
            ok($button_is_present, "Button is present");
        }
        else {
            ok(!$button_is_present, "Button is not present");
        }

        note "Test that a comment can be updated";
        $self->framework->flow_mech__customercare__hold_shipment_submit( { comment => 'Updated Comment' } );
    }


}

=head2 test_shipment_on_Finance_or_DDU_hold

Test that shipment which is already on hold due to Finance or DDU hold cannot
be put onto any other hold.

=cut

sub test_shipment_on_Finance_or_DDU_hold : Tests {
    my $self = shift;

    my $order       = $self->{order};
    my $shipment    = $self->{shipment};

    $order->update({
        order_status_id => $ORDER_STATUS__CREDIT_HOLD,
    });
    $shipment->update ({
        shipment_status_id  => $SHIPMENT_STATUS__FINANCE_HOLD,
    });

    # Test1 : Shipment is on Finance Hold
    $self->framework->flow_mech__customercare__orderview( $order->id )
    ->catch_error(
        qr{Sorry, hold status of Shipment cannot be manually changed due to the current hold reason.},
        'Putting Shipping on Hold is prevented',
        flow_mech__customercare__hold_shipment => ()
    );

    # Tests2 :Shipment on DDU Hold
    $shipment->update ({
        shipment_status_id  => $SHIPMENT_STATUS__DDU_HOLD,
    });

    $self->framework->flow_mech__customercare__orderview( $order->id )
        ->catch_error(
            qr{Sorry, hold status of Shipment cannot be manually changed due to the current hold reason.},
            'Putting Shipping on Hold is prevented',
            flow_mech__customercare__hold_shipment => ()
        );


    #Test3: shipment on any other hold
    $shipment->update ({
        shipment_status_id  => $SHIPMENT_STATUS__HOLD,
    });


    my $hold_reason = $self->{hold_reason_rs}->reset->first;
    $shipment->set_status_hold(
        $self->{operator}->id,
        $hold_reason->id,
        'comment',
    );

    $self->framework->flow_mech__customercare__orderview( $order->id )
         ->flow_mech__customercare__hold_shipment
         ->flow_mech__customercare__hold_release_shipment;
    ok( $shipment->discard_changes->is_processing, "Shipment was taken from Hold succesfully" );

}

#----------------------------------------------------------------------------------

sub framework {
    my $self    = shift;
    return $self->{framework};
}

sub mech {
    my $self    = shift;
    return $self->framework->mech;
}

sub pg_data {
    my $self    = shift;
    return $self->mech->as_data;
}

sub find_link_by_text_on_page {
    my ( $self, $link_text ) = @_;

    my ( $link ) = grep { $_->text && $_->text eq $link_text }
                        $self->mech->followable_links;

    return $link;
}

