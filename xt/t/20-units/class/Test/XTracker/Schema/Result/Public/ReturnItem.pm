package Test::XTracker::Schema::Result::Public::ReturnItem;

use NAP::policy "tt", qw( test class );

BEGIN {
    extends 'NAP::Test::Class';
};

=head1

Tests methods and ResultSet methods of the 'XTracker::Schema::Result::Public::ReturnItem' class.

=cut

use Test::XTracker::Data;
use Test::XT::Data;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_issue_type
                                        :return_item_status
                                        :renumeration_type
                                        :shipment_item_status
                                    );


# this is done once, when the test starts
sub startup : Test( startup => 1 ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{channel}= Test::XTracker::Data->any_channel;
    $self->{domain} = Test::XTracker::Data->returns_domain_using_dump_dir();
}

# done everytime before each Test method is run
sub setup: Test( setup => 4 ) {
    my $self = shift;
    $self->SUPER::setup;

    # Start a transaction, so we can rollback after testing
    $self->schema->txn_begin;

    my $data = Test::XT::Data->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
        ],
    } );

    my $order_details   = $data->dispatched_order(
        channel => $self->{channel},
        products=> 3,
    );
    my $shipment    = $order_details->{shipment_object};
    my @items       = $shipment->shipment_items->all;

    note "Creating a Return";
    my %items_to_return = map { $_->id => { type => 'Return', reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL } } @items;
    my $return  = $self->{domain}->create( {
        operator_id     => $APPLICATION_OPERATOR_ID,
        shipment_id     => $shipment->id,
        pickup          => 0,
        refund_type_id  => $RENUMERATION_TYPE__CARD_REFUND,
        return_items    => \%items_to_return,
    } );
    note "Return Created - RMA: " . $return->rma_number;

    $self->{return}         = $return->discard_changes;
    $self->{return_items}   = [ $return->return_items->search( {}, { order_by => 'shipment_item_id' } )->all ];
}

# done everytime after each Test method has run
sub teardown: Test(teardown) {
    my $self    = shift;
    $self->SUPER::teardown;

    # rollback changes done in a test
    # so they don't affect the next test
    $self->schema->txn_rollback;
}


=head1 TEST METHODS


=head2 test_passed_qc_rs_method

Tests the ResultSet method 'passed_qc'.

=cut

sub test_passed_qc_rs_method : Tests() {
    my $self    = shift;

    my $return      = $self->{return};

    my $got = $return->return_items->passed_qc;
    isa_ok( $got, 'XTracker::Schema::ResultSet::Public::ReturnItem',
                        "'passed_qc' method returned a ResultSet" );

    my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::ReturnItemStatus', {
        allow => [
            $RETURN_ITEM_STATUS__PASSED_QC,
            $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED,
        ],
    } );

    $self->_check_allowed_notallowed_statuses( 'passed_qc', $statuses );
}


=head2 test_failed_qc_awaiting_decision_rs_method

Tests the ResultSet method 'failed_qc_awaiting_decision'.

=cut

sub test_failed_qc_awaiting_decision_rs_method : Tests() {
    my $self    = shift;

    my $return      = $self->{return};
    my $num_items   = $return->return_items->count;

    my $got = $return->return_items->failed_qc_awaiting_decision;
    isa_ok( $got, 'XTracker::Schema::ResultSet::Public::ReturnItem',
                        "'failed_qc_awaiting_decision' method returned a ResultSet" );

    my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::ReturnItemStatus', {
        allow => [
            $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
        ],
    } );

    $self->_check_allowed_notallowed_statuses( 'failed_qc_awaiting_decision', $statuses );
}

=head2 test_beyond_qc_stage_method

Tests the ResultSet method 'beyond_qc_stage'.

=cut

sub beyond_qc_stage_method : Tests() {
    my $self    = shift;

    my $return      = $self->{return};
    my $num_items   = $return->return_items->count;

    my $got = $return->return_items->beyond_qc_stage;
    isa_ok( $got, 'XTracker::Schema::ResultSet::Public::ReturnItem',
                        "'beyond_qc_stage' method returned a ResultSet" );

    my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::ReturnItemStatus', {
        not_allow => [      # easier to say what Statuses are Not Covered
            $RETURN_ITEM_STATUS__AWAITING_RETURN,
            $RETURN_ITEM_STATUS__BOOKED_IN,
            $RETURN_ITEM_STATUS__PASSED_QC,
            $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
            $RETURN_ITEM_STATUS__CANCELLED,
        ],
    } );

    $self->_check_allowed_notallowed_statuses( 'beyond_qc_stage', $statuses );
}

sub test__reverse_item :Tests {
    my ($self) = @_;

    my $return_item = $self->{return_items}->[0];
    my $shipment_item = $return_item->shipment_item();
    my $deliveries_rs = $return_item->return()->deliveries();
    my $delivery_item_rs = $return_item->delivery_items();
    my $stock_process_rs = $delivery_item_rs->related_resultset('stock_processes');

    $return_item->update({
        return_item_status_id => $RETURN_ITEM_STATUS__PASSED_QC,
    });
    note('Created a return item with "Passed QC" status');

    throws_ok(sub {
        $return_item->reverse_item( operator_id => $APPLICATION_OPERATOR_ID );
    }, 'NAP::XT::Exception::Stock::InvalidReturnReverse',
        'reverse_item() throws an exception when attempting to reverse an item '
        . 'that has been QCed');

    $return_item->update({
        return_item_status_id => $RETURN_ITEM_STATUS__BOOKED_IN,
    });
    note('Changed return item status to "Booked In"');

    ok($return_item->reverse_item( operator_id => $APPLICATION_OPERATOR_ID ),
       'reverse_return() returns ok');
    is($return_item->return_item_status_id(), $RETURN_ITEM_STATUS__AWAITING_RETURN,
       'return item status is now "Awaiting Return"');
    is($shipment_item->shipment_item_status_id(), $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
       'shipment item status is now "Return Pending"');
    is($deliveries_rs->search({
        cancel => 1
    })->count(), $deliveries_rs->count(), 'deliveries have been cancelled');
    is($delivery_item_rs->search({
        cancel => 1
    })->count(), $delivery_item_rs->count(), 'delivery items have been cancelled');
    is($stock_process_rs->search({
        complete => 1
    })->count(), $stock_process_rs->count(), 'stock processes are completed');
}

#-----------------------------------------------------------------------------

sub _check_allowed_notallowed_statuses {
    my ( $self, $method_name, $statuses )   = @_;

    my $return      = $self->{return};
    my $num_items   = $return->return_items->count;

    note "Testing Statuses that '${method_name}' should NOT include";
    foreach my $status ( @{ $statuses->{not_allowed} } ) {
        $return->return_items->update( { return_item_status_id => $status->id } );
        cmp_ok(
            $return->return_items->$method_name->count, '==', 0,
            "Status: '" . $status->status . "' is NOT picked up by '${method_name}'"
        );
    }

    note "Testing Statuses that '${method_name}' SHOULD include";
    foreach my $status ( @{ $statuses->{allowed} } ) {
        $return->return_items->update( { return_item_status_id => $status->id } );
        cmp_ok(
            $return->return_items->$method_name->count, '==', $num_items,
            "Status: '" . $status->status . "' IS picked up by '${method_name}'"
        );
    }
}

