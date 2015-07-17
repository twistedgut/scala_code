package Test::XT::DC::Messaging::Plugins::PRL::AllocateResponse;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};

use Test::XT::Data;
use Test::XTracker::Data;
use XT::DC::Messaging::Plugins::PRL::AllocateResponse;
use XTracker::Constants::FromDB qw/
    :allocation_item_status :storage_type :shipment_item_status /;
use Test::XTracker::RunCondition prl_phase => 'prl';
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::AllocateResponse

=head1 DESCRIPTION

Unit tests for XT::DC::Messaging::Plugins::PRL::AllocateResponse

=head1 NOTE

Note that here we just test the interface in to AllocateResponse, namely the
rejection of allocation response messages that don't match what we think we've
sent.

Have a look at L<Test::XTracker::AllocateManager> for tests that are actually
testing the allocation logic.

=cut

sub reject_out_of_date_allocate_response : Tests() {
    my $self = shift;

    # Create an order with two items
    my $data = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );

    my @flat_pids = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => 2
    });
    my $shipment = $data->new_order( products => \@flat_pids, dont_allocate => 1 )
        ->{'shipment_object'};

    my ($si_cancelled, $si_regular) = $shipment->shipment_items;

    # Allocate the shipment, to create the initial allocation items
    $shipment->allocate({
        operator_id => $APPLICATION_OPERATOR_ID
    });

    # Cancel one item
    $si_cancelled->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING });

    # Allocate the shipment, which should update the allocation items
    $shipment->allocate({
        operator_id => $APPLICATION_OPERATOR_ID
    });

    # Check the AI item states are what we'd expect
    $self->check_ai_states(
        "before allocation_response received",
        [ $si_cancelled, $ALLOCATION_ITEM_STATUS__CANCELLED ],
        [ $si_regular,   $ALLOCATION_ITEM_STATUS__REQUESTED ],
    );

    # Setup an allocation_response message
    my $allocation_response_template = $self->message_template(
        AllocateResponse => {
            allocation_id => $si_regular->active_allocation_item->allocation->id,
        }
    );

    # Check we ignore a response about the two items
    my $two_item_message = $allocation_response_template->({
        item_details => [
            {
                client => $si_regular->variant->prl_client,
                sku    => $si_regular->variant->sku,
                quantity_requested => 1,
                quantity_allocated => 1,
            },
            {
                client => $si_cancelled->variant->prl_client,
                sku    => $si_cancelled->variant->sku,
                quantity_requested => 1,
                quantity_allocated => 1,
            },
        ]
    });
    note("Sending an (out-of-date) two item allocation_response");
    lives_ok( sub { $self->send_message( $two_item_message ) },
        "allocation_response handler lived" );

    $self->check_ai_states(
        "after out-of-date allocation_response",
        [ $si_cancelled, $ALLOCATION_ITEM_STATUS__CANCELLED ],
        [ $si_regular,   $ALLOCATION_ITEM_STATUS__REQUESTED ],
    );

    # Create a contemporary allocation_response
    my $one_item_message = $allocation_response_template->({
        item_details => [
            {
                client => $si_regular->variant->prl_client,
                sku    => $si_regular->variant->sku,
                quantity_requested => 1,
                quantity_allocated => 1,
            },
        ]
    });

    note("Sending a correct one item allocation_response");
    lives_ok( sub { $self->send_message( $one_item_message ) },
        "allocation_response handler lived" );

    $self->check_ai_states(
        "after correct allocation_response",
        [ $si_cancelled, $ALLOCATION_ITEM_STATUS__CANCELLED ],
        [ $si_regular,   $ALLOCATION_ITEM_STATUS__ALLOCATED ],
    );
}

sub check_ai_states {
    my ( $self, $message, @tests ) = @_;

    for (@tests) {
        my ( $si, $status ) = @$_;
        my $ai = $si->allocation_items->first;
        is( $ai->status_id, $status,
            sprintf("Allocation Item status for Shipment Item %d is correct %s",
                $si->id, $message
            )
        );
    }
}

sub missing_allocation : Tests {
    my $self = shift;

    my $missing_allocation_id = 84759487;

    # Setup an allocation_response message
    my $allocation_response_template = $self->message_template(
        AllocateResponse => {
            allocation_id => $missing_allocation_id, # Doesn't exist
        }
    );
    my $missing_allocation_message = $allocation_response_template->({
        item_details => [ ],
    });

    my $time_begin = time;
    throws_ok(
        sub { $self->send_message( $missing_allocation_message ) },
        qr/Can't find an allocation with id \[$missing_allocation_id\]/,
        "allocation_response handler dies with missing allocation",
    );

    my $duration = time() - $time_begin;
    cmp_ok(
        $duration, ">", 3,
        "Failing to send message too a long time with all the retries",
    );

}

1;
