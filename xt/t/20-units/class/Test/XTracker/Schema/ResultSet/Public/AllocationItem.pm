package Test::XTracker::Schema::ResultSet::Public::AllocationItem;
use NAP::policy "tt", qw/test class/;
BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::WithSchema';
};
use Carp;
use FindBin::libs;
use List::MoreUtils 'uniq';

use Test::XT::Data;
use Test::XT::Data::Container;
use Test::XTracker::Data;

# Allocation items only exist with PRLs - this is a unit test, however - so
# really it should 'do the right thing' even without PRLs (see
# http://jira4.nap/browse/DCA-1989).
use Test::XTracker::RunCondition prl_phase => 'prl';

=head1 NAME

Test::XTracker::Schema::ResultSet::Public::AllocationItem - Unit tests for
XTracker::Schema::ResultSet::Public::AllocationItem

=head1 DESCRIPTION

Unit tests for XTracker::Schema::ResultSet::Public::AllocationItem

=head1 SYNOPSIS

 # Run all tests
 prove t/20-units/class/Test/XTracker/Schema/ResultSet/Public/AllocationItem.pm

 # Run all tests matching the foo_bar regex
 TEST_METHOD=foobar prove t/20-units/class/Test/XTracker/Schema/ResultSet/Public/AllocationItem.pm

 # For more details, perldoc NAP::Test::Class

=cut

sub startup : Tests(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{order_helper} = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ]
    );
    $self->{products} = [
        Test::XTracker::Data->create_test_products({how_many => 2})
    ];
}

sub distinct_container_ids : Tests {
    my $self = shift;

    # We could really get a shipment in any status here
    my $allocation_item_rs = $self->{order_helper}
        ->picked_order(products => $self->{products})
        ->{order_object}
        ->get_standard_class_shipment
        ->allocations
        ->related_resultset('allocation_items');

    my @container_ids = Test::XT::Data::Container->get_unique_ids({ how_many => 2 });
    # TODO: I'm not *quite* sure what's going on here... but it looks like we
    # have a FK mismatch between allocation_item and shipment_item so
    # place_items_in_containers fails as get_unique_ids gets unique ids but
    # doesn't insert them. Look at whether it's our schema that's weird or we
    # need a wrapper sub (something like create_container? or is there one
    # already?). In the meanwhile insert them.
    $self->schema->resultset('Public::Container')->populate([
        map { +{ id => $_ } } @container_ids
    ]);
    for (
        [ [ undef,             undef,             ], 0 ],
        [ [ $container_ids[0], $container_ids[0], ], 1 ],
        [ [ $container_ids[0], $container_ids[1], ], 2 ],
    ) {
        my ( $container_ids, $expected_count ) = @$_;

        $self->place_items_in_containers([$allocation_item_rs->all], $container_ids);

        my @distinct_container_ids = $allocation_item_rs->distinct_container_ids;
        ok( $_ ~~ \@distinct_container_ids, "distinct_container_ids should include $_" )
            for uniq grep { defined } @$container_ids;
        is( scalar @distinct_container_ids, $expected_count,
            "distinct_container_ids size should be $expected_count" );
    }
}

sub place_items_in_containers {
    my ( $self, $allocation_items, $container_ids ) = @_;

    croak 'the number of items in $allocation_items and $container_ids must match'
        unless @$allocation_items == @$container_ids;

    for my $container_id ( keys @$container_ids ) {
        my $test_name = sprintf('allocation_item %i %s',
            $allocation_items->[$container_id]->id,
            (defined $container_ids->[$container_id]
                ? 'placed into container_id ' . $container_ids->[$container_id]
                : 'not in a container')
        );
        ok( $allocation_items->[$container_id]
                ->update({ picked_into => $container_ids->[$container_id] })
                ->shipment_item->update({ container_id => $container_ids->[$container_id] }),
            $test_name
        );
    }
    return;
}

=head1 SEE ALSO

L<NAP::Test::Class>

L<XTracker::Schema::ResultSet::Public::AllocationItem>

=cut
