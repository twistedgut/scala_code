#!/usr/bin/env perl
use FindBin::libs;
use parent 'NAP::Test::Class';
use NAP::policy "tt", 'test';

=head2 Reservation Source and Type Tests

tests for the 'Public::ReservationSource' & 'Public::ReservationType' class

Currently testing:

* list_by_sort_order - the list of Sources/Type is returned using the 'sort_order' field to sort them
* active_list_by_sort_order - the active list of Sources is returned using the 'sort_order' field to sort them

=cut


use Test::XTracker::Data;

sub start_tests: Tests(startup) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema();
    isa_ok($self->{schema}, 'XTracker::Schema',"Schema Created");

    # start a transaction
    $self->{schema}->txn_begin;
}

sub rollback : Test(shutdown) {
    my $self = shift;

    $self->{schema}->txn_rollback;

}

sub test__source_list_by_sort_order: Tests() {
    my $self = shift;


    note "TEST the 'list_by_sort_order' result set method ReservationSource class";

    my $source_rs   = $self->{schema}->resultset('Public::ReservationSource');


    cmp_ok( $source_rs->count(), '>', 1, "'reservation_source' has more than one Source in it" );

    $self->_test_sort_order($source_rs,'list_by_sort_order');
}

sub test__source_active_list_by_sort_order: Tests() {
    my $self = shift;


    note "TEST the 'active_ist_by_sort_order' result set method of ReservationSource class";

    my $source_rs   = $self->{schema}->resultset('Public::ReservationSource')->search({ is_active => 'true' });

    cmp_ok( $source_rs->count(), '>', 1, "'reservation_source' has more than one Source in it" );

    $self->_test_sort_order($source_rs,'active_list_by_sort_order');
}


sub test__type_list_by_sort_order: Tests() {
    my $self = shift;


    note "TEST the 'list_by_sort_order' result set method of ReservationType class";

    my $source_rs   = $self->{schema}->resultset('Public::ReservationType');


    cmp_ok( $source_rs->count(), '>', 1, "'reservation_type' has more than one Source in it" );

    $self->_test_sort_order($source_rs,'list_by_sort_order');
}

#------------private methods
sub _test_sort_order {
    my $self        = shift;
    my $resultset   = shift;
    my $method_name = shift;

    # get all sources/Types and sort them manually
    my @results = sort { $a->sort_order <=> $b->sort_order } $resultset->all;

    # swap around first & last sort orders
    my $beyond_range_sort_order = $results[-1]->sort_order + 1;
    my $first_sort_order= $results[0]->sort_order;
    my $last_sort_order = $results[-1]->sort_order;
    my $swap_store      = $results[0];
    $results[-1]->update( { sort_order => $beyond_range_sort_order } );       # to avoid unique index on 'sort_order' field use a
                                                                              # value 1 bigger than current max 'sort_order'
    $results[0]->update( { sort_order => $last_sort_order } );
    $results[-1]->update( { sort_order => $first_sort_order } );
    $results[0] = $results[-1];
    $results[-1]= $swap_store;

    # call 'list_by_sort_order' method and compare list orders
    my @list_results    = $resultset->$method_name->all;
    is_deeply(
                [ map { $_->id } @list_results ],
                [ map { $_->id } @results ],
                "Order of Sources/Types using 'list_by_sort_order' method is in 'sort_order' field order"
        );

}

Test::Class->runtests;
