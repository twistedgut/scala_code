package Test::NAP::CustomerCare::OrderSearch::OrderView;

use NAP::policy     qw( test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::NAP::CustomerCare::OrderSearch::OrderView

=head1 DESCRIPTION

This tests the Order View page and any simple actions that can be performed from it.

Some of the simpler Sidenav options may be tested here but any thing that isn't a simple
action should have its own Test Class.

=cut

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB     qw( :note_type :department );

sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    $self->{framework}  = Test::XT::Flow->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
            'Test::XT::Data::Return',
            'Test::XT::Flow::CustomerCare',
        ],
    } );

    $self->framework->login_with_roles( {
        main_nav => [
            'Customer Care/Customer Search',
            'Customer Care/Order Search',
        ],
        # this is required to get access to the Order View page
        setup_fallback_perms => 1,
    } );
    $self->{operator} = $self->mech->logged_in_as_object;
}

sub shutdown : Test( shutdown ) {
    my $self    = shift;

    $self->SUPER::shutdown;
}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;

    my $order_details   = $self->framework->dispatched_order(
        products    => 2,
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

=head2 test_acl_fraud_rule_sidenav_options

Tests the ACL protection for the 'Fraud Rules' Sidenav options, makes sure
that they are seen and reachable only with the correct Roles.

The options that will be checked are:
    * Show Outcome
    * Test Using Live
    * Test Using Staging

=cut

sub test_acl_protection_for_fraud_rule_sidenav_options : Tests {
    my $self = shift;

    my $framework = $self->framework;
    my $mech      = $self->mech;

    # list of Sidenav options to check each time
    my @options_to_check = (
        'Show Outcome',
        'Test Using Live',
        'Test Using Staging',
    );

    # get the right & wrong Roles for the Sidenav options
    my $wrong_roles = $self->mech->get_roles_for_url_paths( [ '/Admin/FraudRules' ] );
    my $right_roles = $self->mech->get_roles_for_url_paths( [ qw(
        /Finance/FraudRules/Outcome
        /Finance/FraudRules/Test
    ) ] );

    my $order = $self->{order};

    # Log-In with no Roles
    $framework->login_with_roles( {
        dept => undef,
        # need the following to allow access to the Order View page
        main_nav => [
            'Customer Care/Order Search',
            'Customer Care/Customer Search',
        ],
    } );
    my $session = $mech->session;

    note "test with NO Roles that Options can't be seen";
    $framework->flow_mech__customercare__orderview( $order->id );
    $mech->hasnt_sidenav_options( \@options_to_check );

    note "test with the Wrong Role and check that Options can't be seen";
    $session->add_acl_roles( $wrong_roles );
    $framework->flow_mech__customercare__orderview( $order->id );
    $mech->hasnt_sidenav_options( \@options_to_check );

    note "test with the Right Role and make sure Options can be seen";
    $session->remove_acl_roles( $wrong_roles );
    $session->add_acl_roles( $right_roles );
    $framework->flow_mech__customercare__orderview( $order->id );
    $mech->has_sidenav_options( \@options_to_check );

    note "Remove the Right Role and then make sure each Option can't be accessed";
    $session->remove_acl_roles( $right_roles );
    $framework->test_for_no_permissions(
        "Can't use 'Show Outcome' without the correct Role",
        'flow_mech__customercare__fraud_rules__show_outcome',
    );
    $session->add_acl_roles( $right_roles );
    $framework->flow_mech__customercare__orderview( $order->id );
    $session->remove_acl_roles( $right_roles );
    $framework->test_for_no_permissions(
        "Can't use 'Test Using Live' without the correct Role",
        'flow_mech__customercare__fraud_rules__test_using_live',
    );
    $session->add_acl_roles( $right_roles );
    $framework->flow_mech__customercare__orderview( $order->id );
    $session->remove_acl_roles( $right_roles );
    $framework->test_for_no_permissions(
        "Can't use 'Test Using Staging' without the correct Role",
        'flow_mech__customercare__fraud_rules__test_using_staging',
    );

    note "Add the Right Role and then make sure each Option can be accessed";
    $session->add_acl_roles( $right_roles );
    $framework->flow_mech__customercare__orderview( $order->id )
                    ->flow_mech__customercare__fraud_rules__show_outcome
              ->flow_mech__customercare__orderview( $order->id )
                    ->flow_mech__customercare__fraud_rules__test_using_live
              ->flow_mech__customercare__orderview( $order->id )
                    ->flow_mech__customercare__fraud_rules__test_using_staging
    ;
}

=head2 test_order_notes_shown_correctly

Tests that the 'Notes' section on the Order View page shows the correct
Notes that are assigned to an Order, Shipment and/or Return and that
when some Notes have the Same Creation Time that they are ALL still shown.

=cut

sub test_order_notes_shown_correctly : Tests() {
    my $self = shift;

    my $framework = $self->framework;

    my $order    = $self->{order};
    my $shipment = $self->{shipment};
    my $return   = $framework->new_return( { shipment_id => $shipment->id } );

    # clear out any Notes that might have been created
    $order->discard_changes->order_notes->delete;
    $shipment->discard_changes->shipment_notes->delete;
    $return->discard_changes->return_notes->delete;


    note "Check Order View page doesn't show Note section when they're NONE to be shown";
    $framework->flow_mech__customercare__orderview( $order->id );
    my $pg_data = $self->pg_data()->{meta_data};
    ok( !defined $pg_data->{order_notes}, "Notes section not found on page" )
                    or diag "ERROR - Notes section was found: " . p( $pg_data->{order_notes} );


    note "Create two Notes each for the Order, Shipment & Return records, each will be created at a different Time";
    my $note_counter = 0;
    my @notes;

    # create 2 notes for each record
    push @notes, $self->_create_note( $order,    'order_notes',    'Order Note: '    . ++$note_counter );
    push @notes, $self->_create_note( $shipment, 'shipment_notes', 'Shipment Note: ' . ++$note_counter );
    push @notes, $self->_create_note( $return,   'return_notes',   'Return Note: '   . ++$note_counter );
    push @notes, $self->_create_note( $order,    'order_notes',    'Order Note: '    . ++$note_counter );
    push @notes, $self->_create_note( $shipment, 'shipment_notes', 'Shipment Note: ' . ++$note_counter );
    push @notes, $self->_create_note( $return,   'return_notes',   'Return Note: '   . ++$note_counter );

    $framework->flow_mech__customercare__orderview( $order->id );
    $pg_data = $self->pg_data()->{meta_data};
    my @expected = map { superhashof( $_->{expected} ) } @notes;
    cmp_deeply( $pg_data->{order_notes}, \@expected, "Order Notes with different Creation Times are shown as Expected" )
                    or diag "ERROR - Notes were NOT found as Expected:\n"
                          . "Got: " . p( $pg_data->{order_notes} )
                          . "Expected: " . p( @expected );


    note "Update all the Order Notes with the Same Time and check they still ALL appear on the page";
    my $note_date = $self->schema->db_now();
    $_->{record}->discard_changes->update( { date => $note_date } )     foreach ( @notes );

    $framework->flow_mech__customercare__orderview( $order->id );
    $pg_data = $self->pg_data()->{meta_data};
    cmp_deeply( $pg_data->{order_notes}, bag( @expected ), "Order Notes with Same Time are ALL shown as Expected" )
                    or diag "ERROR - Notes with Same Time were NOT found as Expected:\n"
                          . "Got: " . p( $pg_data->{order_notes} )
                          . "Expected: " . p( @expected );
}

=head2 test_store_credit_refund_per_channel

Creates dispatched orders for 4 channels: Jimmy Choo, NAP and MrP and The Outnet.
Checks that for Jimmy Choo only, the option of giving a Store Credit is disabled
whereas it is enabled for the other channels.

=cut

sub test_store_credit_refund_per_channel : Tests {
    my $self = shift;

    my $framework = $self->framework;
    my $order = $self->{order};

    my $deeply_original = $self->mech->client_parse_cell_deeply();
    $self->mech->client_parse_cell_deeply(1);

    # update operator to be customer care manager
    $self->{operator}->update( { department_id => $DEPARTMENT__CUSTOMER_CARE_MANAGER } );

    # get the available channels as this will differ per DC
    my $available_channels = Test::XTracker::Data->get_enabled_channels;

    while (my $channel = $available_channels->next ) {
        note 'Testing channel ' . $channel->name;

        # if channel is JC then store credit should be disabled.
        my $store_credit_disabled = $channel->is_on_jc ? 1 : 0;

        my $order_details = $framework->dispatched_order(
            products => 1,
            channel => $channel
        );
        $order = $order_details->{order_object};

        $framework->flow_mech__customercare__orderview( $order->id )
            ->flow_mech__customercare__view_returns
            ->flow_mech__customercare__view_returns_create_return;

        my $data = $self->mech->as_data;

        is(
            $data->{returns_create}->{refund_type}->{inputs}[0]->{input_readonly},
            $store_credit_disabled,
            'Store Credit option as expected on Create Return page'
        );

        # navigate to the second page and repeat the tests
        $framework->flow_mech__customercare__orderview( $order->id )
            ->flow_mech__customercare_create_debit_credit;

        $data = $self->mech->as_data;

        is(
            $data->{invoice_details}->{Type}->{select_values}[0][2],
            $store_credit_disabled,
            'Store Credit option as expected on Credit/Debit page'
        );
    }

    # restore the original setting so as not to risk breaking tests elsewhere
    $self->mech->client_parse_cell_deeply($deeply_original);
}

#----------------------------------------------------------------------------------

# create a '_note' record for an
# Order, Shipment or Return record
sub _create_note {
    my ( $self, $object, $relationship, $note_text ) = @_;

    my $note = $object->create_related( $relationship, {
        note         => $note_text,
        note_type_id => $NOTE_TYPE__FINANCE,
        operator_id  => $self->{operator}->id,
        date         => \'now()',
    } )->discard_changes;

    # work out what is expected to be shown on the page
    my $class = ref( $object );
    $class    =~ s/.*:://;
    $class    = 'Order'     if ( $class eq 'Orders' );

    my $value;
    $value = $object->order_nr      if ( $class eq 'Order' );
    $value = $object->id            if ( $class eq 'Shipment' );
    $value = $object->rma_number    if ( $class eq 'Return' );

    return {
        expected => {
            # this part is what should be shown on the Page
            'Relating To' => $value,
            Class         => $class,
            Note          => $note_text,
        },
        record => $note,
    };
}

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
