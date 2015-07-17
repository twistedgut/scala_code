package XTracker::Schema::Role::ResultSet::GroupBy;
use NAP::policy "tt", "role";

=head1 NAME

XTracker::Schema::Role::ResultSet::GroupBy

=head1 DESCRIPTION

Provide ->aliased_columns and ->group_by_result_source.

Note that this is composed into the ResultSetBase, but also
individually in some ResultSets which can't inherit from ResultSetBase
because of the overridden ->first method.

(This breaks some things in a weird way,
e.g. lib/XTracker/Schema/Result/Public/Orders.pm ->
get_standard_class_shipment. I can not for the life of me get that to
work without breaking invalid_shipment.t)

=cut

requires "current_source_alias";
requires "result_source";
requires "search";


=head1 METHODS

=head2 aliased_columns($alias = current_source_alias ) : @aliased_column_names

Return the column names for this ResultSet, but fully qualified with
the $alias prepended (which by default is the current table alias).

=cut

sub aliased_columns {
    my ($self, $alias) = @_;
    $alias //= $self->current_source_alias;
    return
        map { "$alias.$_" }
        $self->result_source->columns;
}

=head2 group_by_result_source() : $rs | @rows

Add a group_by with all the columns in the result_source of this
resultset.

This is useful if the query joins in other tables and you don't want
duplicates.

Note: This won't be necessary with Pg 9.2 which allows a group_by on
only the PK (or a unique column), the rest of the columns can then be
inferred.

Note: the returned resultset can't be used for e.g. an ->update (DBIC
will complain).

=cut

sub group_by_result_source {
    my $self = shift;
    $self->search(
        {},
        { group_by => [ $self->aliased_columns ] },
    );
}


