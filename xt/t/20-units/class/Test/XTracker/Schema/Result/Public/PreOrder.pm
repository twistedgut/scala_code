package  Test::XTracker::Schema::Result::Public::PreOrder;
use NAP::policy     qw( test class );

BEGIN {
    extends 'NAP::Test::Class';
};

=head1 NAME

Test::XTracker::Schema::Result::Public::PreOrder

=head1 DESCRIPTION

Tests the L<XTracker::Schema::Result::Public::PreOrder> class.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;


# Checks the class being tested can be loaded OK.
sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();
}

# Begins a database transaction.
sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->schema->txn_begin;
}

# Rolls back the database transaction.
sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback;
}


=head1 TESTS

=head2 test_all_items_are_exported

This tests the 'all_items_are_exported' method to make sure it returns
TRUE or FALSE correctly based on the status of the Pre-Order Items.

=cut

sub test_all_items_are_exported : Tests() {
    my $self = shift;

    # return a Pre-Order with 5 Pre-Order Items all marked as 'Complete'
    my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order();
    my @items     = $pre_order->pre_order_items->all;
    my $num_items = scalar( @items );

    # get the Item Statuses into a Hash keyed by Status
    # so that it can be used easily in the test setup
    my %item_status = map {
        $_->status => $_,
    } $self->rs('Public::PreOrderItemStatus')->all;

    my %tests = (
        "All Items set as 'Exported', method should return TRUE" => {
            # specify an Array Ref. of Item Statuses that will
            # be used to set the Status of each item in the
            # @items array respectively
            setup  => [ map { 'Exported' } 1..$num_items ],
            expect => 1,
        },
        "All Items set as 'Cancelled', method should return FALSE" => {
            setup  => [ map { 'Cancelled' } 1..$num_items ],
            expect => 0,
        },
        "All Items set as 'Complete', method should return FALSE" => {
            setup  => [ map { 'Complete' } 1..$num_items ],
            expect => 0,
        },
        "Items set to a mixture of Statuses, method should return FALSE" => {
            setup  => [ qw( Selected Confirmed Complete Exported Cancelled ) ],
            expect => 0,
        },
        "Some Items set to be 'Complete' & some set to 'Cancelled', method should return FALSE" => {
            setup  => [ qw( Complete Complete Cancelled Complete Cancelled ) ],
            expect => 0,
        },
        "Some Items set to be 'Complete' & some set to 'Exported', method should return FALSE" => {
            setup  => [ qw( Complete Complete Exported Complete Exported ) ],
            expect => 0,
        },
        "Some Items set to be 'Complete' or 'Exported' & some set to 'Cancelled', method should return FALSE" => {
            setup  => [ qw( Complete Cancelled Exported Complete Exported ) ],
            expect => 0,
        },
        "Some Items set to 'Exported' & some set to 'Cancelled', method should return TRUE" => {
            setup  => [ qw( Exported Exported Cancelled Exported Cancelled ) ],
            expect => 1,
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # set-up the Item Statuses
        foreach my $idx ( 0..$#{ $setup } ) {
            my $item   = $items[ $idx ];
            my $status = $item_status{ $setup->[ $idx ] };

            $item->discard_changes->update( { pre_order_item_status_id => $status->id } );
        }

        my $got = $pre_order->discard_changes->all_items_are_exported;

        cmp_ok( $got, '==', $expect, "'all_items_are_exported' returned as Expected" );
    }
}

