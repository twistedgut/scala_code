package Test::XTracker::Schema::ResultSet::Public::AllocationStatusPackSpaceAllocationTime;
use NAP::policy "test", "class";
BEGIN {
    extends 'NAP::Test::Class';
    with qw/Test::Role::WithSchema/;
};
use Test::XTracker::RunCondition (
    prl_phase => "prl",
);

=head1 METHODS

=head2 rs_count

Return the number od rows in a resultset. Name of the resultset is passed
in as a string.

=cut

sub rs_count {
    my ($self, $resultset) = @_;
    return $self->schema->resultset("Public::$resultset")->count;
}

=head2 test__rows_for_all_combinations

Test that all combinations of AllocationStatus and
PrlPackSpaceAllocationTime have a matching row in
AllocationStatusPackSpaceAllocationTime.

=cut

sub test__rows_for_all_combinations :Tests {
    my ($self) = @_;

    my $expected_count =
          $self->rs_count("AllocationStatus")
        * $self->rs_count("PrlPackSpaceAllocationTime");
    is(
        $self->rs_count("AllocationStatusPackSpaceAllocationTime"),
        $expected_count,
        "There is a row for each combination of allocation_status and
        pack_space_time. If this fails, look at the SQL patch
        60-dca-3481-allocation_status_pack_space_allocation_time.sql
        for how to easily add more.",
    );
}
